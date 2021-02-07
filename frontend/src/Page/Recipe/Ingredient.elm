module Page.Recipe.Ingredient exposing (Ingredient, fromString, scale, toString)

import Parser
    exposing
        ( (|.)
        , (|=)
        , Parser
        , andThen
        , backtrackable
        , chompUntilEndOr
        , chompWhile
        , commit
        , deadEndsToString
        , end
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
    { prefix : Maybe String
    , quantity : Maybe Float
    , ingredient : String
    }


fromString : String -> Result String Ingredient
fromString input =
    Parser.run parser input |> Result.mapError deadEndsToString


parser : Parser Ingredient
parser =
    succeed Ingredient
        |= oneOf
            [ succeed Just |= prefixParser
            , succeed Nothing
            ]
        |= oneOf
            [ succeed Just |= quantityParser
            , succeed Nothing
            ]
        |. spaces
        |= getChompedString (chompUntilEndOr "\n")


type alias Prefix =
    { prefix : String, badEnding : Bool }


prefixParser : Parser String
prefixParser =
    succeed Prefix
        |= backtrackable (getChompedString (chompWhile (Char.isDigit >> not)))
        -- Look ahead to make sure it is actually a prefix, and not the entire string we just chomped
        |= oneOf
            [ map (\_ -> True) (backtrackable end)
            , succeed False
            ]
        |> andThen
            (\{ prefix, badEnding } ->
                if badEnding || String.isEmpty prefix || String.length prefix > 5 then
                    problem "not a prefix to a quantity"

                else
                    commit prefix
            )


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
myFloatToFloat { num, decimals } =
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
toString { prefix, quantity, ingredient } =
    let
        prefixString =
            prefix |> Maybe.withDefault ""

        floatWithComma =
            String.fromFloat >> String.replace "." ","

        quantityString =
            quantity |> Maybe.map (floatWithComma >> (\q -> q ++ " ")) |> Maybe.withDefault ""
    in
    prefixString
        ++ quantityString
        ++ ingredient


scale : Float -> Ingredient -> Ingredient
scale factor ({ prefix, quantity, ingredient } as original) =
    case quantity of
        Nothing ->
            original

        Just q ->
            { prefix = prefix
            , quantity = Just (q * factor)
            , ingredient = ingredient
            }
