module Page.Recipe.Ingredient exposing (Ingredient, fromString, scale, toString)

import Parser exposing ((|.), (|=), Parser, deadEndsToString, float, getChompedString, int, keyword, map, number, oneOf, spaces, succeed)


type alias Ingredient =
    { quantity : Float
    , unit : String
    , ingredient : String
    }


fromString : String -> Result String Ingredient
fromString input =
    Parser.run parser input |> Result.mapError deadEndsToString


parser : Parser Ingredient
parser =
    succeed Ingredient
        |= quantityParser
        |. spaces
        |= getChompedString (keyword "kg")
        |. spaces
        |= getChompedString (keyword "mjöl")


quantityParser : Parser Float
quantityParser =
    oneOf
        [ float
        , map toFloat int
        ]


toString : Ingredient -> String
toString { quantity, unit, ingredient } =
    String.fromFloat quantity ++ " " ++ unit ++ " " ++ ingredient


scale : Float -> Ingredient -> Ingredient
scale factor { quantity, unit, ingredient } =
    { quantity = quantity * factor
    , unit = unit
    , ingredient = ingredient
    }
