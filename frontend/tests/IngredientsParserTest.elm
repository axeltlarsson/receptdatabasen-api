module IngredientsParserTest exposing (tests)

import Expect
import Recipe.IngredientsParser exposing (parseIngredients)
import Test exposing (..)



-- remove all leading whitespace in multiline string


normalizeMarkdown : String -> String
normalizeMarkdown md =
    String.join "\n" (List.map String.trim (String.lines md))


tests : Test
tests =
    describe "IngredientsParser"
        [ test "parses a simple unordered list" <|
            \_ ->
                let
                    markdown =
                        normalizeMarkdown
                            """
                            - 1 kg mjöl
                            - 1/2 dl vatten
                            """
                in
                Expect.equal
                    (parseIngredients markdown)
                    [ "1 kg mjöl", "1/2 dl vatten" ]
        , test "parses a complex markdown with multiple lists" <|
            \_ ->
                let
                    markdown =
                        normalizeMarkdown
                            """
                            ## Chokladtårta
                            * 125 g smör
                            * 3 dl strösocker
                            * 1 ½ tsk vaniljsocker
                            * 4 msk kakao
                            * ½ tsk flingsalt
                            * 1 ½ dl vetemjöl
                            * 2 ägg

                            ## Hallongrädde
                            * 3 dl vispgrädde
                            * 225 g hallon
                            * 1 dl florsocker
                            """
                in
                Expect.equal
                    (parseIngredients markdown)
                    [ "125 g smör"
                    , "3 dl strösocker"
                    , "1 ½ tsk vaniljsocker"
                    , "4 msk kakao"
                    , "½ tsk flingsalt"
                    , "1 ½ dl vetemjöl"
                    , "2 ägg"
                    , "3 dl vispgrädde"
                    , "225 g hallon"
                    , "1 dl florsocker"
                    ]
        , test "returns an empty list for invalid markdown" <|
            \_ ->
                Expect.equal
                    (parseIngredients "Invalid Markdown")
                    []
        ]
