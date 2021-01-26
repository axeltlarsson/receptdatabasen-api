module Recipe exposing
    ( Full
    , ImageUrl(..)
    , Metadata
    , Preview
    , Recipe(..)
    , ServerError(..)
    , contents
    , create
    , delete
    , edit
    , expectJsonWithBody
    , fetch
    , fetchMany
    , fullDecoder
    , httpErrorToString
    , metadata
    , previewDecoder
    , search
    , slug
    , uploadImage
    , viewServerError
    )

{- The interface to the Recipe data structure.

   This includes:
       - The Recipe type itself
       - Ways to make HTTP requests to retrieve and modify recipes
       - Ways to access information about a Recipe
       - Converting between various types
-}

import Dict exposing (Dict)
import Element exposing (Element, column, el, text)
import Element.Font as Font
import File exposing (File)
import Http exposing (Expect)
import Json.Decode as Decode exposing (Decoder, dict, field, index, int, list, map2, map8, maybe, string, value)
import Json.Encode as Encode
import Palette
import Recipe.Slug as Slug exposing (Slug)
import Url
import Url.Builder exposing (QueryParameter)



-- TYPES
{- A recipe, optionally with contents -}


type Recipe a
    = Recipe Metadata a


type alias Metadata =
    { id : Int
    , title : Slug
    , description : Maybe String
    , images : List Image
    , createdAt : String
    , updatedAt : String
    }


type alias Image =
    { url : String
    , blurHash : Maybe String
    }


type Preview
    = Preview


type Full
    = Full Contents


type alias Contents =
    { instructions : String
    , tags : List String
    , portions : Int
    , ingredients : String
    }



-- EXPORT


metadata : Recipe a -> Metadata
metadata (Recipe data _) =
    data


contents : Recipe Full -> Contents
contents (Recipe _ (Full c)) =
    c


slug : Recipe a -> Slug
slug (Recipe md _) =
    md.title



-- (DE)SERIALIZATION


metadataDecoder : Decoder Metadata
metadataDecoder =
    Decode.map6 Metadata
        (field "id" int)
        (field "title" Slug.decoder)
        (field "description" <| Decode.nullable string)
        (field "images" <|
            Decode.list <|
                Decode.map2 Image
                    (Decode.field "url" <| string)
                    (Decode.maybe (Decode.field "blur_hash" <| string))
        )
        (field "created_at" string)
        (field "updated_at" string)


previewDecoder : Decoder (Recipe Preview)
previewDecoder =
    Decode.map2 Recipe
        metadataDecoder
        (Decode.succeed Preview)


xDecoder : Decoder Contents
xDecoder =
    Decode.map4 Contents
        (field "instructions" string)
        (field "tags" (list string))
        (field "portions" int)
        (field "ingredients" string)


contentsDecoder : Decoder Full
contentsDecoder =
    Decode.map Full xDecoder


fullDecoder : Decoder (Recipe Full)
fullDecoder =
    Decode.map2 Recipe
        metadataDecoder
        contentsDecoder


previewsDecoder : Decoder (List (Recipe Preview))
previewsDecoder =
    list <| previewDecoder



-- HTTP


restUrl : List QueryParameter -> String
restUrl queryParams =
    Url.Builder.crossOrigin "/rest" [ "recipes" ] queryParams


fetch : Slug -> (Result ServerError (Recipe Full) -> msg) -> Cmd msg
fetch recipeSlug toMsg =
    Http.request
        { url = restUrl [ Url.Builder.string "title" "eq." ] ++ Slug.toString recipeSlug
        , method = "GET"
        , timeout = Nothing
        , tracker = Nothing
        , headers = [ Http.header "Accept" "application/vnd.pgrst.object+json" ]
        , body = Http.emptyBody
        , expect = expectJsonWithBody toMsg fullDecoder
        }


fetchMany : (Result ServerError (List (Recipe Preview)) -> msg) -> Cmd msg
fetchMany toMsg =
    let
        params =
            [ Url.Builder.string "select" "id,title,description,images,created_at,updated_at"
            , Url.Builder.string "order" "created_at.desc"
            ]
    in
    Http.get
        { url = restUrl params
        , expect = expectJsonWithBody toMsg previewsDecoder
        }


search : (Result ServerError (List (Recipe Preview)) -> msg) -> String -> Cmd msg
search toMsg query =
    let
        params =
            [ Url.Builder.string "search_query" query ]

        searchUrl queryParams =
            Url.Builder.crossOrigin "/rest" [ "rpc", "search" ] queryParams
    in
    Http.get
        { url = searchUrl params
        , expect = expectJsonWithBody toMsg previewsDecoder
        }


delete : Slug -> (Result ServerError () -> msg) -> Cmd msg
delete recipeSlug toMsg =
    Http.request
        { url = restUrl [ Url.Builder.string "title" "eq." ] ++ Slug.toString recipeSlug
        , method = "DELETE"
        , timeout = Nothing
        , tracker = Nothing
        , headers = []
        , body = Http.emptyBody
        , expect = expectJsonWithBody toMsg (Decode.succeed ())
        }


create : Encode.Value -> (Result ServerError (Recipe Full) -> msg) -> Cmd msg
create jsonForm toMsg =
    Http.request
        { url = restUrl []
        , method = "POST"
        , timeout = Nothing
        , tracker = Nothing
        , headers =
            [ Http.header "Prefer" "return=representation"
            , Http.header "Accept" "application/vnd.pgrst.object+json"
            ]
        , body = Http.jsonBody jsonForm
        , expect = expectJsonWithBody toMsg fullDecoder
        }


edit : Slug -> Encode.Value -> (Result ServerError (Recipe Full) -> msg) -> Cmd msg
edit recipeSlug jsonForm toMsg =
    Http.request
        { url = restUrl [ Url.Builder.string "title" "eq." ] ++ Slug.toString recipeSlug
        , method = "PATCH"
        , timeout = Nothing
        , tracker = Nothing
        , headers =
            [ Http.header "Prefer" "return=representation"
            , Http.header "Accept" "application/vnd.pgrst.object+json"
            ]
        , body = Http.jsonBody jsonForm
        , expect = expectJsonWithBody toMsg fullDecoder
        }


uploadImage : Int -> File -> (Result ServerError ImageUrl -> msg) -> Cmd msg
uploadImage idx file toMsg =
    Http.request
        { url = "/images/upload"
        , method = "POST"
        , timeout = Nothing
        , tracker = Just ("image" ++ String.fromInt idx)
        , headers = []
        , body = Http.fileBody file
        , expect = expectJsonWithBody toMsg imageUrlDecoder
        }


type ImageUrl
    = ImageUrl String


imageUrlDecoder : Decode.Decoder ImageUrl
imageUrlDecoder =
    Decode.map ImageUrl (field "image" (field "url" string))


expectJsonWithBody : (Result ServerError a -> msg) -> Decoder a -> Expect msg
expectJsonWithBody toMsg decoder =
    Http.expectStringResponse toMsg <|
        \response ->
            case response of
                Http.BadUrl_ urll ->
                    Err (otherError (Http.BadUrl urll) Nothing)

                Http.Timeout_ ->
                    Err (otherError Http.Timeout Nothing)

                Http.NetworkError_ ->
                    Err (otherError Http.NetworkError Nothing)

                Http.BadStatus_ { url, statusCode, statusText, headers } body ->
                    case statusCode of
                        401 ->
                            Err Unauthorized

                        _ ->
                            Err (otherError (Http.BadStatus statusCode) (Just body))

                Http.GoodStatus_ md body ->
                    case Decode.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err (otherError (Http.BadBody (Decode.errorToString err)) (Just body))



{--
  - ServerError
  - I specifically care about Unauthorized case - then we want to redirect to /login
  - otherwise, I keep the type opaque, modules are expected to basically just pass it to
  - viewServerError, if they wish to display the error to user
  --}


type ServerError
    = Unauthorized
    | Error OtherError


type OtherError
    = OtherError Http.Error (Maybe Body)


otherError : Http.Error -> Maybe Body -> ServerError
otherError httpError body =
    Error (OtherError httpError body)


type alias Body =
    String


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl str ->
            "BadUrl " ++ str

        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "NetworkError"

        Http.BadStatus code ->
            "BadStatus " ++ String.fromInt code

        Http.BadBody str ->
            "BadBody " ++ str


viewServerError : String -> ServerError -> Element msg
viewServerError prefix serverError =
    case serverError of
        Error (OtherError httpError Nothing) ->
            column []
                [ el [ Font.heavy ] (text prefix)
                , text <| httpErrorToString httpError
                ]

        Error (OtherError httpError (Just body)) ->
            column []
                [ el [ Font.heavy ] (text prefix)
                , text <| httpErrorToString httpError
                , text body
                ]

        Unauthorized ->
            column []
                [ el [ Font.heavy ] (text prefix)
                , text "401 Unauthorized"
                ]
