module RouteTest exposing (..)

import Expect
import Json.Decode as Decode
import Recipe.Slug
import Route
import Test exposing (..)



-- Check out https://package.elm-lang.org/packages/elm-explorations/test/latest to learn more about testing in Elm!


all : Test
all =
    describe "Route.toString"
        [ test "Recipe" <|
            \_ ->
                let
                    decoder =
                        Decode.field "title" Recipe.Slug.decoder

                    slug =
                        Decode.decodeString decoder "{\"title\": \"fläskpannkaka i ugn\"}"

                    actual =
                        case slug of
                            Err err ->
                                Decode.errorToString err

                            Ok s ->
                                Route.toString (Route.Recipe s)
                in
                Expect.equal actual "/recipe/fl%C3%A4skpannkaka%20i%20ugn"
        , test "RecipeList" <|
            \_ ->
                let
                    actual =
                        Route.toString (Route.RecipeList Nothing)
                in
                Expect.equal actual "/"
        , test "RecipeList with search" <|
            \_ ->
                let
                    actual =
                        Route.toString (Route.RecipeList (Just "fläskpannkaka i ugn"))
                in
                Expect.equal actual "/?search=fl%C3%A4skpannkaka%20i%20ugn"
        , test "NewRecipe" <|
            \_ ->
                let
                    actual =
                        Route.toString Route.NewRecipe
                in
                Expect.equal actual "/editor"
        , test "Login" <|
            \_ ->
                let
                    actual =
                        Route.toString Route.Login
                in
                Expect.equal actual "/login"
        ]
