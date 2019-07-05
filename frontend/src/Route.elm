module Route exposing (Route(..), fromUrl)

import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser, int, map, oneOf, s, string)



-- ROUTING


type Route
    = Recipe Int
    | RecipeList



-- | NewRecipe
-- | EditRecipe Int


parser : Parser (Route -> a) a
parser =
    oneOf
        [ map Recipe (s "recipes" </> int)
        , map RecipeList (s "recipes")

        -- , map RecipeQuery (s "recipes" <?> Query.string "search")
        ]



-- PUBLIC HELPERS


fromUrl : Url -> Maybe Route
fromUrl url =
    Parser.parse parser url
