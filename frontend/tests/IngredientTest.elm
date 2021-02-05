module IngredientTest exposing (..)

import Expect
import Page.Recipe.Ingredient as Ingredient
import Test exposing (..)


all : Test
all =
    describe "Ingredient"
        [ test "fromString float" <|
            \_ ->
                let
                    ingredient =
                        Ingredient.fromString "1.0 kg mjöl"

                    str =
                        ingredient
                            |> Result.map Ingredient.toString
                            |> Result.withDefault ""
                in
                Expect.equal str "1 kg mjöl"
        , test "fromString int" <|
            \_ ->
                let
                    ingredient =
                        Ingredient.fromString "1 kg mjöl"

                    str =
                        ingredient
                            |> Result.map Ingredient.toString
                            |> Result.withDefault ""
                in
                Expect.equal str "1 kg mjöl"
        ]
