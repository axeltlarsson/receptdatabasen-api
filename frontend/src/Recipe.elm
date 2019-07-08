module Recipe exposing (Full, Metadata, Preview, Recipe(..), contents, fullDecoder, metadata, previewDecoder)

{- The interface to the Recipe data structure.

   This includes:
       - The Recipe type itself
       - Ways to make HTTP requests to retrieve and modify recipes
       - Ways to access information about a Recipe
       - Converting between various types
-}

import Dict exposing (Dict)
import Json.Decode as Decoder exposing (Decoder, dict, field, index, int, list, map2, map8, string, value)



-- TYPES
{- A recipe, optionally with contents -}


type Recipe a
    = Recipe Metadata a


type alias Metadata =
    { slug : Int
    , title : String
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
    , quantity : Int
    , ingredients : Dict String (List String)
    }



-- EXPORT


metadata : Recipe a -> Metadata
metadata (Recipe data _) =
    data


contents : Recipe Full -> Contents
contents (Recipe _ (Full c)) =
    c



-- (DE)SERIALIZATION


metadataDecoder : Decoder Metadata
metadataDecoder =
    Decoder.map4 Metadata
        (field "id" int)
        (field "title" string)
        (field "created_at" string)
        (field "updated_at" string)


previewDecoder : Decoder (List (Recipe Preview))
previewDecoder =
    list <|
        Decoder.map2 Recipe
            metadataDecoder
            (Decoder.succeed Preview)


xDecoder : Decoder Contents
xDecoder =
    Decoder.map5 Contents
        (field "description" string)
        (field "instructions" string)
        (field "tags" (list string))
        (field "quantity" int)
        (field "ingredients" (dict (list string)))


contentsDecoder : Decoder Full
contentsDecoder =
    Decoder.map Full xDecoder


fullDecoder : Decoder (List (Recipe Full))
fullDecoder =
    list <|
        Decoder.map2 Recipe
            metadataDecoder
            contentsDecoder
