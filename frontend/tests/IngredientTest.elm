module IngredientTest exposing (..)

import Expect
import Page.Recipe.Ingredient as Ingredient
import Test exposing (..)


ingredients : List String -> List (Result String String)
ingredients strings =
    strings
        |> List.map Ingredient.fromString
        |> List.map (Result.map Ingredient.toString)



-- TODO: assert structure of the ingredients - only looking at the string can be deceiving


all : Test
all =
    describe "Ingredient"
        [ describe "fromString"
            [ test "floats" <|
                \_ ->
                    Expect.equal
                        [ Ok "1 kg mjöl"
                        , Ok "1,2 l mjölk"
                        , Ok "1,1 l chicken broth see"
                        , Ok "123,456 l maizena"
                        ]
                    <|
                        ingredients
                            [ "1 kg mjöl"
                            , "1,2 l mjölk"
                            , "1,1l chicken broth see"
                            , "123,456 l maizena"
                            ]
            , test "fractions" <|
                \_ ->
                    Expect.equal
                        [ Ok "0,5 st red jalapeno pepper sliced, or a couple Thai chiles, halved"
                        , Ok "0,75 onion, sliced"
                        , Ok "2,75 dl socker"
                        , Ok "3 /0 dl kakao" -- TODO: ideally the 3 should not be parsed as a quantity here, so that scaling is disabled
                        ]
                    <|
                        ingredients
                            [ "1/2 st red jalapeno pepper sliced, or a couple Thai chiles, halved"
                            , "3/4 onion, sliced"
                            , "2 3/4 dl socker"
                            , "3/0 dl kakao"
                            ]
            , test "basic" <|
                \_ ->
                    Expect.equal
                        [ Ok "1 kg mjöl"
                        , Ok "1 kruka dill"
                        , Ok "peppar"
                        , Ok "salt"
                        , Ok "förp soppa (gärna skärgårdssoppa, à 5 dl)"
                        , Ok "1 msk coconut oil"
                        , Ok "2 st garlic cloves chopped"
                        , Ok "3 st quarter-inch slices slices galangal or ginger"
                        , Ok "1 st lemongrass stalk pounded with the side of a knife and cut into 2-inch long pieces"
                        , Ok "2 tsk red Thai curry paste"
                        , Ok "2 st medium chicken breasts cut into bite-sized pieces, see Note 2 for vegan/vegetarian or to use shrimp"
                        , Ok "250 g white mushroom caps sliced"
                        , Ok "fresh cilantro (sv. koriander) chopped, for garnish"
                        ]
                    <|
                        ingredients
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
                            , "2 st medium chicken breasts cut into bite-sized pieces, see Note 2 for vegan/vegetarian or to use shrimp"
                            , "250 g white mushroom caps sliced"
                            , "fresh cilantro (sv. koriander) chopped, for garnish"
                            ]
            , skip <|
                test "ranges" <|
                    \_ ->
                        Expect.equal
                            [ Ok "1-2 msk coconut sugar (alt brunt farinsocker)"
                            , Ok "1 1/2 - 2 msk fish sauce plus more to taste"
                            , Ok "2-3 msk fresh lime juice"
                            , Ok "2-3 msk green onions (sv. saladslök) sliced thin"
                            ]
                        <|
                            ingredients
                                [ "1-2 msk coconut sugar (alt brunt farinsocker)"
                                , "1 1/2 - 2 msk fish sauce plus more to taste"
                                , "2-3 msk fresh lime juice"
                                , "2-3 msk green onions (sv. saladslök) sliced thin"
                                ]
            , test "prefixes" <|
                \_ ->
                    let
                        scaled =
                            [ "ca 7 dl havregryn" ]
                                |> List.map Ingredient.fromString
                                |> List.map (Result.map (Ingredient.scale 2))
                                |> List.map (Result.map Ingredient.toString)
                    in
                    Expect.equal
                        [ Ok "ca 14 dl havregryn" ]
                    <|
                        scaled
            ]
        ]
