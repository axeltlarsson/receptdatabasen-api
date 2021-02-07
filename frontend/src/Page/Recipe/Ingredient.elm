module Page.Recipe.Ingredient exposing (Ingredient, fromString, scale, toString)

import Parser
    exposing
        ( (|.)
        , (|=)
        , Parser
        , andThen
        , backtrackable
        , chompUntilEndOr
        , commit
        , deadEndsToString
        , float
        , getChompedString
        , int
        , map
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
        [ backtrackable mixedNumberParser |> andThen mixedNumberToFloat
        , backtrackable fractionsParser |> andThen fractionToFloat
        , backtrackable myFloatParser |> andThen myFloatToFloat
        , map toFloat int
        ]


type alias MyFloat =
    { num : Int
    , sep : String
    , decimals : Int
    }


myFloatParser : Parser MyFloat
myFloatParser =
    succeed MyFloat
        |= int
        |= getChompedString (oneOf [ token ",", token "." ])
        |= int


myFloatToFloat : MyFloat -> Parser Float
myFloatToFloat { num, sep, decimals } =
    let
        maybeFloat =
            String.fromInt num
                ++ "."
                ++ String.fromInt decimals
                |> String.toFloat
    in
    case maybeFloat of
        Nothing ->
            problem "could not parse float"

        Just f ->
            commit f


type alias MixedNumber =
    { integer : Int
    , fraction : Fraction
    }


type alias Fraction =
    { numerator : Int
    , denominator : Int
    }


mixedNumberParser : Parser MixedNumber
mixedNumberParser =
    succeed MixedNumber
        |= int
        |. spaces
        |= fractionsParser


fractionsParser : Parser Fraction
fractionsParser =
    succeed Fraction
        |= int
        |. token "/"
        |= int


fractionToFloat : Fraction -> Parser Float
fractionToFloat { numerator, denominator } =
    case denominator of
        0 ->
            problem "cannot divide by zero"

        _ ->
            commit (toFloat numerator / toFloat denominator)


mixedNumberToFloat : MixedNumber -> Parser Float
mixedNumberToFloat { integer, fraction } =
    fractionToFloat fraction |> map (\f -> toFloat integer + f)


toString : Ingredient -> String
toString { quantity, ingredient } =
    let
        floatWithComma =
            String.fromFloat >> String.replace "." ","

        quantityString =
            quantity |> Maybe.map (floatWithComma >> (\q -> q ++ " ")) |> Maybe.withDefault ""
    in
    Debug.log ("quantity: " ++ Debug.toString quantity) <|
        quantityString
            ++ ingredient


scale : Float -> Ingredient -> Ingredient
scale factor ({ quantity, ingredient } as original) =
    case quantity of
        Nothing ->
            original

        Just q ->
            { quantity = Just (q * factor)
            , ingredient = ingredient
            }
