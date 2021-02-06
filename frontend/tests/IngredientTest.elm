module IngredientTest exposing (..)

import Expect
import Page.Recipe.Ingredient as Ingredient
import Test exposing (..)


all : Test
all =
    describe "Ingredient"
        [ describe "fromString"
            [ test "floats" <|
                \_ ->
                    let
                        ingredients =
                            List.map Ingredient.fromString
                                [ "1 kg mjöl"
                                , "1,2 l mjölk"
                                , "1,1 l chicken broth see"
                                , "123,456 l maizena"
                                ]

                        strings =
                            List.map (Result.map Ingredient.toString) ingredients
                    in
                    Expect.equal strings
                        [ Ok "1 kg mjöl"
                        , Ok "1,2 l mjölk"
                        , Ok "1,1 l chicken broth see"
                        , Ok "123,456 l maizena"
                        ]
            , skip <|
                test "fractions" <|
                    \_ ->
                        let
                            ingredients =
                                List.map Ingredient.fromString
                                    [ "1 kg mjöl"

                                    -- , "1/2 st red jalapeno pepper sliced, or a couple Thai chiles, halved"
                                    -- , "1/2 onion, sliced"
                                    ]

                            strings =
                                List.map (Result.map Ingredient.toString) ingredients
                        in
                        Expect.equal strings
                            []
            , test "basic" <|
                \_ ->
                    let
                        ingredients =
                            List.map Ingredient.fromString
                                [ "1 kg mjöl"
                                , "1 kruka dill"
                                , "peppar"
                                , "salt"
                                , "förp soppa (gärna skärgårdssoppa, à 5 dl)"
                                , "1 msk coconut oil"
                                , "2 st garlic cloves chopped"
                                , "3 st quarter-inch slices slices galangal or ginger"
                                , "1 st lemongrass stalk pounded with the side of a knife and cut into 2-inch long pieces"
                                , "2 tsk red Thai curry paste"

                                -- , "1,1l canned coconut cream or coconut milk"
                                , "2 st medium chicken breasts cut into bite-sized pieces, see Note 2 for vegan/vegetarian or to use shrimp"
                                , "250 g white mushroom caps sliced"

                                -- , "1-2 msk coconut sugar (alt brunt farinsocker)"
                                -- , "1 1/2 - 2 msk fish sauce plus more to taste"
                                -- , "2-3 msk fresh lime juice"
                                -- , "2-3 msk green onions (sv. saladslök) sliced thin"
                                , "fresh cilantro (sv. koriander) chopped, for garnish"
                                ]

                        strings =
                            List.map (Result.map Ingredient.toString) ingredients
                    in
                    Expect.equal strings
                        [ Ok "1 kg mjöl"
                        , Ok "1 kruka dill"
                        , Ok "peppar"
                        , Ok "salt"
                        , Ok "förp soppa (gärna skärgårdssoppa, à 5 dl)"
                        , Ok "1 msk coconut oil"

                        -- , Ok "1/2 onion, sliced"
                        , Ok "2 st garlic cloves chopped"

                        -- , Ok "1/2 st red jalapeno pepper sliced, or a couple Thai chiles, halved"
                        , Ok "3 st quarter-inch slices slices galangal or ginger"
                        , Ok "1 st lemongrass stalk pounded with the side of a knife and cut into 2-inch long pieces"
                        , Ok "2 tsk red Thai curry paste"

                        -- , Ok "1,1l canned coconut cream or coconut milk"
                        , Ok "2 st medium chicken breasts cut into bite-sized pieces, see Note 2 for vegan/vegetarian or to use shrimp"
                        , Ok "250 g white mushroom caps sliced"

                        -- , Ok "1-2 msk coconut sugar (alt brunt farinsocker)"
                        -- , Ok "1 1/2 - 2 msk fish sauce plus more to taste"
                        -- , Ok "2-3 msk fresh lime juice"
                        -- , Ok "2-3 msk green onions (sv. saladslök) sliced thin"
                        , Ok "fresh cilantro (sv. koriander) chopped, for garnish"
                        ]
            ]
        ]
