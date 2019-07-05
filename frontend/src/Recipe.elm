module Recipe exposing (Full, Internals, Metadata, Preview, Recipe(..), previewDecoder)

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
    = Recipe Internals a


type alias Internals =
    { slug : Int
    , metadata : Metadata
    }


type alias Metadata =
    { title : String
    , createdAt : String
    , updatedAt : String
    }


type Preview
    = Preview


type Full
    = Full Contents


type Contents
    = Contents
        { description : String
        , instructions : String
        , tags : List String
        , quantity : Int
        , ingredients : Dict String (List String)
        }



-- (DE)SERIALIZATION


metadataDecoder : Decoder Metadata
metadataDecoder =
    Decoder.map3 Metadata
        (field "title" string)
        (field "created_at" string)
        (field "updated_at" string)


internalsDecoder : Decoder Internals
internalsDecoder =
    Decoder.map2 Internals
        (field "slug" int)
        metadataDecoder


previewDecoder : Decoder (List (Recipe Preview))
previewDecoder =
    list <|
        Decoder.map2 Recipe
            internalsDecoder
            (Decoder.succeed Preview)
