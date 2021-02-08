module IngredientTest exposing (..)

import Expect
import Page.Recipe.Ingredient as Ingredient
import Test exposing (..)


ingredients : List String -> List (Result String String)
ingredients strings =
    strings
        |> List.map Ingredient.fromString
        |> List.map (Result.map Ingredient.toString)


scaledIngredients : Float -> List String -> List (Result String String)
scaledIngredients scale strings =
    strings
        |> List.map Ingredient.fromString
        |> List.map (Result.map (Ingredient.scale scale))
        |> List.map (Result.map Ingredient.toString)


all : Test
all =
    describe "Ingredient"
        [ describe "fromString"
            [ only <|
                test "floats" <|
                    \_ ->
                        Expect.equal
                            [ Ok "1 kg mjöl"
                            , Ok "1,2 l mjölk"
                            , Ok "1,1 l chicken broth see"
                            , Ok "123,46 l maizena"
                            , Ok "3,02 dl majs"
                            ]
                        <|
                            ingredients
                                [ "1 kg mjöl"
                                , "1,2 l mjölk"
                                , "1,1l chicken broth see"
                                , "123,456 l maizena"
                                , "3,015 dl majs" -- TODO: this is parsed as quantity = 3 and ",015 dl majs" as the ingredient
                                ]
            , test "fractions" <|
                \_ ->
                    Expect.equal
                        [ Ok "0,5 st red jalapeno pepper sliced, or a couple Thai chiles, halved"
                        , Ok "0,75 onion, sliced"
                        , Ok "2,75 dl socker"
                        , Ok "3 /0 dl kakao" -- TODO: ideally the 3 should not be parsed as a quantity here, so that scaling is disabled
                        , Ok "0,33 dl mjölk"
                        ]
                    <|
                        ingredients
                            [ "1/2 st red jalapeno pepper sliced, or a couple Thai chiles, halved"
                            , "3/4 onion, sliced"
                            , "2 3/4 dl socker"
                            , "3/0 dl kakao"
                            , "1/3 dl mjölk"
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
            , test "ranges" <|
                \_ ->
                    Expect.equal
                        [ Ok "1 - 2 msk coconut sugar (alt brunt farinsocker)"
                        , Ok "1,5 - 2 msk fish sauce plus more to taste"
                        , Ok "2 - 3 msk fresh lime juice"
                        , Ok "2 - 3 msk green onions (sv. saladslök) sliced thin"
                        , Ok "2 - 2,75 dl polentagryn"
                        , Ok "2,88 - 3,75 dl cashewnötter"
                        ]
                    <|
                        ingredients
                            [ "1-2 msk coconut sugar (alt brunt farinsocker)"
                            , "1 1/2 - 2 msk fish sauce plus more to taste"
                            , "2-3 msk fresh lime juice"
                            , "2-3 msk green onions (sv. saladslök) sliced thin"
                            , "2 - 2 3/4 dl polentagryn"
                            , "2 7/8 - 3 3/4 dl cashewnötter"
                            ]
            , test "prefixes" <|
                \_ ->
                    Expect.equal
                        [ Ok "ca 7 dl havregryn" ]
                    <|
                        ingredients [ "ca 7 dl havregryn" ]
            ]
        , describe "scale"
            [ test "basic" <|
                \_ ->
                    Expect.equal
                        [ Ok "1,5 kg mjöl"
                        , Ok "1,5 kruka dill"
                        , Ok "peppar"
                        , Ok "salt"
                        , Ok "förp soppa (gärna skärgårdssoppa, à 5 dl)"
                        , Ok "1,5 msk coconut oil"
                        , Ok "3 st garlic cloves chopped"
                        , Ok "4,5 st quarter-inch slices slices galangal or ginger"
                        , Ok "1,5 st lemongrass stalk pounded with the side of a knife and cut into 2-inch long pieces"
                        , Ok "3 tsk red Thai curry paste"
                        , Ok "3 st medium chicken breasts cut into bite-sized pieces, see Note 2 for vegan/vegetarian or to use shrimp"
                        , Ok "375 g white mushroom caps sliced"
                        , Ok "fresh cilantro (sv. koriander) chopped, for garnish"
                        ]
                    <|
                        scaledIngredients 1.5
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
            , test "prefixes" <|
                \_ ->
                    Expect.equal
                        [ Ok "ca 14 dl havregryn" ]
                    <|
                        scaledIngredients 2 [ "ca 7 dl havregryn" ]
            , test "ranges" <|
                \_ ->
                    Expect.equal
                        [ Ok "3 - 6 msk coconut sugar (alt brunt farinsocker)"
                        , Ok "4,5 - 6 msk fish sauce plus more to taste"
                        , Ok "6 - 9 msk fresh lime juice"
                        , Ok "6 - 9 msk green onions (sv. saladslök) sliced thin"
                        , Ok "6 - 8,25 dl polentagryn"
                        , Ok "8,63 - 11,25 dl cashewnötter"
                        ]
                    <|
                        scaledIngredients 3
                            [ "1-2 msk coconut sugar (alt brunt farinsocker)"
                            , "1 1/2 - 2 msk fish sauce plus more to taste"
                            , "2-3 msk fresh lime juice"
                            , "2-3 msk green onions (sv. saladslök) sliced thin"
                            , "2 - 2 3/4 dl polentagryn"
                            , "2 7/8 - 3 3/4 dl cashewnötter"
                            ]
            ]
        ]
