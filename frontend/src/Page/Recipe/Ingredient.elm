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
        , symbol
        , token
        )
import Round


type Ingredient
    = Ingredient IngredientRecord


type alias IngredientRecord =
    { prefix : Maybe String
    , quantity : Maybe Quantity
    , ingredient : String
    }


type Quantity
    = Number Float
    | Range Float String Float


fromString : String -> Result String Ingredient
fromString input =
    Parser.run parser input |> Result.mapError deadEndsToString


parser : Parser Ingredient
parser =
    succeed IngredientRecord
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
        |> map Ingredient


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


quantityParser : Parser Quantity
quantityParser =
    oneOf
        [ backtrackable rangeParser
        , backtrackable mixedNumberParser |> andThen mixedNumberToQuantity
        , backtrackable fractionsParser |> andThen fractionToQuantity
        , backtrackable myFloatParser |> map Number
        , map (toFloat >> Number) int
        ]


type alias MyFloat =
    { num : String
    , sep : String
    , decimals : String
    }


myFloatParser : Parser Float
myFloatParser =
    succeed MyFloat
        |= getChompedString (chompWhile Char.isDigit)
        |= getChompedString (oneOf [ token ",", token "." ])
        |= getChompedString (chompWhile Char.isDigit)
        |> andThen
            (\{ num, decimals } ->
                num
                    ++ "."
                    ++ decimals
                    |> String.toFloat
                    |> Maybe.map commit
                    |> Maybe.withDefault (problem "could not parse float")
            )


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


fractionToQuantity : Fraction -> Parser Quantity
fractionToQuantity { numerator, denominator } =
    case denominator of
        0 ->
            problem "cannot divide by zero"

        _ ->
            commit (Number <| toFloat numerator / toFloat denominator)


mixedNumberToQuantity : MixedNumber -> Parser Quantity
mixedNumberToQuantity { integer, fraction } =
    fractionToQuantity fraction
        |> andThen
            (\q ->
                case q of
                    Number f ->
                        commit (Number <| toFloat integer + f)

                    Range _ _ _ ->
                        problem "cannot have a range in a mixed number"
            )


toFloatParser : Quantity -> Parser Float
toFloatParser q =
    case q of
        Number f ->
            commit f

        Range _ _ _ ->
            problem "cannot convert a range to a simple float"


rangeParser : Parser Quantity
rangeParser =
    succeed Range
        |= oneOf
            [ backtrackable mixedNumberParser |> andThen mixedNumberToQuantity |> andThen toFloatParser
            , backtrackable myFloatParser
            , map toFloat int
            ]
        |. spaces
        |= getChompedString (symbol "-")
        |. spaces
        |= oneOf
            [ backtrackable mixedNumberParser |> andThen mixedNumberToQuantity |> andThen toFloatParser
            , backtrackable myFloatParser
            , map toFloat int
            ]


{-| Take a float and turn it into a string, rounding it down to use a maximum of 2 decimals
-}
floatToString : Float -> String
floatToString f =
    Round.roundNum 2 f |> String.fromFloat |> String.replace "." ","


toString : Ingredient -> String
toString (Ingredient { prefix, quantity, ingredient }) =
    let
        prefixString =
            prefix |> Maybe.withDefault ""

        quantityString =
            case quantity of
                Nothing ->
                    ""

                Just (Number f) ->
                    floatToString f ++ " "

                Just (Range i sep j) ->
                    floatToString i ++ " " ++ sep ++ " " ++ floatToString j ++ " "
    in
    prefixString
        ++ quantityString
        ++ ingredient


scale : Float -> Ingredient -> Ingredient
scale factor ((Ingredient { prefix, quantity, ingredient }) as original) =
    case quantity of
        Nothing ->
            original

        Just (Number q) ->
            Ingredient
                { prefix = prefix
                , quantity = Just (Number <| q * factor)
                , ingredient = ingredient
                }

        Just (Range i sep j) ->
            Ingredient
                { prefix = prefix
                , quantity = Just (Range (i * factor) sep (j * factor))
                , ingredient = ingredient
                }
