module Recipe exposing
    ( Full
    , ImageUrl(..)
    , Metadata
    , Preview
    , Recipe(..)
    , contents
    , create
    , delete
    , edit
    , exportToShoppingList
    , fetch
    , fetchMany
    , id
    , metadata
    , search
    , slug
    , uploadImage
    )

{- The interface to the Recipe data structure.

   This includes:
       - The Recipe type itself
       - Ways to make HTTP requests to retrieve and modify recipes
       - Ways to access information about a Recipe
       - Converting between various types
-}

import Api exposing (ServerError, expectJsonWithBody)
import File exposing (File)
import Http
import Json.Decode as Decode exposing (Decoder, field, int, list, string)
import Json.Encode as Encode
import Recipe.IngredientsParser exposing (parseIngredients)
import Recipe.Slug as Slug exposing (Slug)
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
    { url : String }


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


id : Recipe a -> Int
id (Recipe md _) =
    md.id



-- (DE)SERIALIZATION


metadataDecoder : Decoder Metadata
metadataDecoder =
    Decode.map6 Metadata
        (field "id" int)
        (field "title" Slug.decoder)
        (field "description" <| Decode.nullable string)
        (field "images" <|
            Decode.list <|
                Decode.map Image (Decode.field "url" <| string)
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
        , timeout = Just 30000 -- ms = 5 seconds
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
        , timeout = Just 30000 -- ms = 5 seconds
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
        , timeout = Just 30000 -- ms = 5 seconds
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
        , timeout = Just 30000 -- ms = 5 seconds
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
        , timeout = Just 30000 -- ms = 5 seconds
        , tracker = Just ("image" ++ String.fromInt idx)
        , headers = []
        , body = Http.fileBody file
        , expect = expectJsonWithBody toMsg imageUrlDecoder
        }


exportToShoppingList : String -> (Result ServerError String -> msg) -> Cmd msg
exportToShoppingList ingredientStr toMsg =
    let
        ingredients =
            parseIngredients ingredientStr
    in
    Http.request
        { url = "/export_to_list"
        , method = "POST"
        , timeout = Just 30000 -- ms = 5 seconds
        , tracker = Nothing
        , headers = []
        , body = Http.jsonBody (Encode.object [ ( "ingredients", Encode.list Encode.string ingredients ) ])
        , expect = expectJsonWithBody toMsg (Decode.field "list_name" string)
        }


type ImageUrl
    = ImageUrl String


imageUrlDecoder : Decode.Decoder ImageUrl
imageUrlDecoder =
    Decode.map ImageUrl (field "image" (field "url" string))
