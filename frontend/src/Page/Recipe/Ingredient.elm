module Page.Recipe.Ingredient exposing (Ingredient, fromString, scale, toString)

import Parser
    exposing
        ( (|.)
        , (|=)
        , Parser
        , andThen
        , backtrackable
        , chompUntilEndOr
        , deadEndsToString
        , end
        , float
        , getChompedString
        , int
        , keyword
        , map
        , number
        , oneOf
        , problem
        , spaces
        , succeed
        , token
        )


type alias Ingredient =
    { quantity : Maybe Float
    , ingredient : String
    }


fromString : String -> Result String Ingredient
fromString input =
    Parser.run parser input |> Result.mapError deadEndsToString


parser : Parser Ingredient
parser =
    succeed Ingredient
        |= oneOf
            [ succeed Just |= quantityParser
            , succeed Nothing
            ]
        |. spaces
        |= getChompedString (chompUntilEndOr "\n")


quantityParser : Parser Float
quantityParser =
    oneOf
        [ floatParser
        , map toFloat int
        ]


type alias MyFloat =
    { num : Int, sep : String, decimals : Int }


myFloatParser : Parser MyFloat
myFloatParser =
    succeed MyFloat
        |= int
        |= getChompedString (oneOf [ token ",", token "." ])
        |= int


floatParser : Parser Float
floatParser =
    backtrackable
        (map
            (\{ num, sep, decimals } ->
                String.fromInt num
                    ++ "."
                    ++ String.fromInt decimals
                    |> String.toFloat
            )
            myFloatParser
            |> andThen
                (\x ->
                    case x of
                        Just float ->
                            succeed float

                        Nothing ->
                            problem "could not parse float"
                )
        )


toString : Ingredient -> String
toString { quantity, ingredient } =
    let
        floatWithComma =
            String.fromFloat >> String.replace "." ","

        quantityString =
            quantity |> Maybe.map (floatWithComma >> (\q -> q ++ " ")) |> Maybe.withDefault ""
    in
    quantityString ++ ingredient


scale : Float -> Ingredient -> Ingredient
scale factor ({ quantity, ingredient } as original) =
    case quantity of
        Nothing ->
            original

        Just q ->
            { quantity = Just (q * factor)
            , ingredient = ingredient
            }
