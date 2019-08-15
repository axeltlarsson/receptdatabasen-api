module Recipe exposing (Full, Metadata, Preview, Recipe(..), contents, fetch, fullDecoder, metadata, previewDecoder, slug)

{- The interface to the Recipe data structure.

   This includes:
       - The Recipe type itself
       - Ways to make HTTP requests to retrieve and modify recipes
       - Ways to access information about a Recipe
       - Converting between various types
-}

import Dict exposing (Dict)
import Http exposing (Expect)
import Json.Decode as Decoder exposing (Decoder, dict, field, index, int, list, map2, map8, maybe, string, value)
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
    Decoder.map4 Metadata
        (field "id" int)
        (field "title" Slug.decoder)
        (field "created_at" string)
        (field "updated_at" string)


previewDecoder : Decoder (Recipe Preview)
previewDecoder =
    Decoder.map2 Recipe
        metadataDecoder
        (Decoder.succeed Preview)


xDecoder : Decoder Contents
xDecoder =
    Decoder.map5 Contents
        (field "description" string)
        (field "instructions" string)
        (field "tags" (list string))
        (field "portions" int)
        (field "ingredients" (dict (list string)))


contentsDecoder : Decoder Full
contentsDecoder =
    Decoder.map Full xDecoder


fullDecoder : Decoder (Recipe Full)
fullDecoder =
    Decoder.map2 Recipe
        metadataDecoder
        contentsDecoder


fetchUrl : String
fetchUrl =
    Url.Builder.crossOrigin "http://localhost:3000" [ "recipes" ] [ Url.Builder.string "title" "eq." ]


fetch : Slug -> (Result Http.Error (Recipe Full) -> msg) -> Cmd msg
fetch recipeSlug toMsg =
    Http.request
        { url = fetchUrl ++ Slug.toString recipeSlug
        , method = "GET"
        , timeout = Nothing
        , tracker = Nothing
        , headers = [ Http.header "Accept" "application/vnd.pgrst.object+json" ]
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg fullDecoder
        }
