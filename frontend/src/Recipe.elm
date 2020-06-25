module Recipe exposing
    ( Full
    , ImageUrl(..)
    , Metadata
    , Preview
    , Recipe(..)
    , ServerError
    , contents
    , create
    , delete
    , edit
    , fetch
    , fetchMany
    , fullDecoder
    , httpErrorToString
    , metadata
    , previewDecoder
    , search
    , serverErrorFromHttp
    , serverErrorToString
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
    , images : List String
    , createdAt : String
    , updatedAt : String
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
        (field "images" <| Decode.list <| Decode.field "url" <| string)
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


url : List QueryParameter -> String
url queryParams =
    Url.Builder.crossOrigin "http://localhost:8080/rest" [ "recipes" ] queryParams


fetch : Slug -> (Result ServerError (Recipe Full) -> msg) -> Cmd msg
fetch recipeSlug toMsg =
    Http.request
        { url = url [ Url.Builder.string "title" "eq." ] ++ Slug.toString recipeSlug
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
            , Url.Builder.string "order" "title"
            ]
    in
    Http.get
        { url = url params
        , expect = expectJsonWithBody toMsg previewsDecoder
        }


search : (Result ServerError (List (Recipe Preview)) -> msg) -> String -> Cmd msg
search toMsg query =
    let
        params =
            [ Url.Builder.string "search_query" query ]

        searchUrl queryParams =
            Url.Builder.crossOrigin "http://localhost:8080/rest" [ "rpc", "search" ] queryParams
    in
    Http.get
        { url = searchUrl params
        , expect = expectJsonWithBody toMsg previewsDecoder
        }


delete : Slug -> (Result Http.Error () -> msg) -> Cmd msg
delete recipeSlug toMsg =
    Http.request
        { url = url [ Url.Builder.string "title" "eq." ] ++ Slug.toString recipeSlug
        , method = "DELETE"
        , timeout = Nothing
        , tracker = Nothing
        , headers = []
        , body = Http.emptyBody
        , expect = Http.expectWhatever toMsg
        }


create : Encode.Value -> (Result ServerError (Recipe Full) -> msg) -> Cmd msg
create jsonForm toMsg =
    Http.request
        { url = url []
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
        { url = url [ Url.Builder.string "title" "eq." ] ++ Slug.toString recipeSlug
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
        { url = "http://localhost:8080/images/upload"
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
                    Err (ServerError (Http.BadUrl urll))

                Http.Timeout_ ->
                    Err (ServerError Http.Timeout)

                Http.NetworkError_ ->
                    Err (ServerError Http.NetworkError)

                Http.BadStatus_ md body ->
                    Err (ServerErrorWithBody (Http.BadStatus md.statusCode) (decodeServerError body))

                Http.GoodStatus_ md body ->
                    case Decode.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err (ServerError (Http.BadBody (Decode.errorToString err)))



{--
  - ServerError
  --}


type ServerError
    = ServerError Http.Error
    | ServerErrorWithBody Http.Error PGError


type alias PGError =
    { message : String
    , details : Maybe String
    , code : Maybe String
    , hint : Maybe String
    }


serverErrorFromHttp : Http.Error -> ServerError
serverErrorFromHttp =
    ServerError


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


serverErrorToString : ServerError -> String
serverErrorToString error =
    case error of
        ServerError httpErr ->
            httpErrorToString httpErr

        ServerErrorWithBody httpErr pgError ->
            httpErrorToString httpErr ++ " " ++ pgErrorToString pgError


viewServerError : String -> ServerError -> Element msg
viewServerError prefix serverError =
    case serverError of
        ServerError httpError ->
            column []
                [ el [ Font.heavy ] (text prefix)
                , text <| httpErrorToString httpError
                ]

        ServerErrorWithBody httpError pgError ->
            column []
                [ el [ Font.heavy ] (text prefix)
                , text <| httpErrorToString httpError
                , viewPgError pgError
                ]


viewPgError : PGError -> Element msg
viewPgError error =
    column [ Font.color Palette.red ]
        [ text error.message
        , text <| Maybe.withDefault "" error.details
        ]


pgErrorDecoder : Decode.Decoder PGError
pgErrorDecoder =
    Decode.map4 PGError
        (Decode.field "message" Decode.string)
        (Decode.field "details" <| Decode.nullable Decode.string)
        (Decode.field "code" <| Decode.nullable Decode.string)
        (Decode.field "hint" <| Decode.nullable Decode.string)


pgErrorToString : PGError -> String
pgErrorToString err =
    "message: "
        ++ err.message
        ++ "\n"
        ++ "details: "
        ++ Maybe.withDefault "" err.details
        ++ "\n"
        ++ "code: "
        ++ Maybe.withDefault "" err.code
        ++ "\n"
        ++ "hint: "
        ++ Maybe.withDefault "" err.hint
        ++ "\n"


decodeServerError : String -> PGError
decodeServerError str =
    case Decode.decodeString pgErrorDecoder str of
        Err err ->
            { message = "Error! I ouldn't decode the PostgREST error response "
            , code = Nothing
            , details = Just <| Decode.errorToString err
            , hint = Nothing
            }

        Ok pgError ->
            pgError
