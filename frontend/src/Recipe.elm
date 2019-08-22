module Recipe exposing
    ( Full
    , Metadata
    , Preview
    , Recipe(..)
    , ServerError(..)
    , contents
    , create
    , delete
    , edit
    , fetch
    , fullDecoder
    , metadata
    , previewDecoder
    , serverErrorToString
    , slug
    )

{- The interface to the Recipe data structure.

   This includes:
       - The Recipe type itself
       - Ways to make HTTP requests to retrieve and modify recipes
       - Ways to access information about a Recipe
       - Converting between various types
-}

import Dict exposing (Dict)
import Http exposing (Expect)
import Json.Decode as Decode exposing (Decoder, dict, field, index, int, list, map2, map8, maybe, string, value)
import Json.Encode as Encode
import Recipe.Slug as Slug exposing (Slug)
import Url
import Url.Builder



-- TYPES
{- A recipe, optionally with contents -}


type Recipe a
    = Recipe Metadata a


type alias Metadata =
    { id : Int
    , title : Slug
    , createdAt : String
    , updatedAt : String
    }


type Preview
    = Preview


type Full
    = Full Contents


type alias Contents =
    { description : String
    , instructions : String
    , tags : List String
    , portions : Int
    , ingredients : Dict String (List String)
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
    Decode.map4 Metadata
        (field "id" int)
        (field "title" Slug.decoder)
        (field "created_at" string)
        (field "updated_at" string)


previewDecoder : Decoder (Recipe Preview)
previewDecoder =
    Decode.map2 Recipe
        metadataDecoder
        (Decode.succeed Preview)


xDecoder : Decoder Contents
xDecoder =
    Decode.map5 Contents
        (field "description" string)
        (field "instructions" string)
        (field "tags" (list string))
        (field "portions" int)
        (field "ingredients" (dict (list string)))


contentsDecoder : Decoder Full
contentsDecoder =
    Decode.map Full xDecoder


fullDecoder : Decoder (Recipe Full)
fullDecoder =
    Decode.map2 Recipe
        metadataDecoder
        contentsDecoder



-- HTTP


url : List Url.Builder.QueryParameter -> String
url queryParams =
    Url.Builder.crossOrigin "http://localhost:3000" [ "recipes" ] queryParams


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


delete : Slug -> (Result Http.Error () -> msg) -> Cmd msg
delete recipeSlug toMsg =
    Http.request
        { url = url [] ++ Slug.toString recipeSlug
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
edit slug_ jsonForm toMsg =
    Http.request
        { url = url [ Url.Builder.string "title" (String.concat [ "eq.", Slug.toString slug_ ]) ]
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
                    Err (ServerErrorWithBody (Http.BadStatus md.statusCode) body)

                Http.GoodStatus_ md body ->
                    case Decode.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err (ServerError (Http.BadBody (Decode.errorToString err)))


type ServerError
    = ServerError Http.Error
    | ServerErrorWithBody Http.Error String


serverErrorToString : ServerError -> String
serverErrorToString error =
    let
        httpErrorStr err =
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
    in
    case error of
        ServerError httpErr ->
            httpErrorStr httpErr

        ServerErrorWithBody httpErr str ->
            httpErrorStr httpErr ++ " " ++ str
