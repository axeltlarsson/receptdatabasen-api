module Route exposing (Route(..), fromUrl, href, pushUrl, replaceUrl, toString)

import Browser.Navigation as Nav
import Html exposing (Attribute)
import Html.Attributes as Attr
import Recipe.Slug as Slug exposing (Slug)
import Url exposing (Url)
import Url.Builder
import Url.Parser as Parser exposing ((</>), (<?>), Parser, int, map, oneOf, s, string)
import Url.Parser.Query as Query



-- ROUTING


type Route
    = Recipe Slug
    | RecipeList (Maybe String)
    | NewRecipe
    | EditRecipe Slug
    | Login


parser : Parser (Route -> a) a
parser =
    oneOf
        [ map Recipe (s "recipe" </> Slug.urlParser)
        , map RecipeList (Parser.top <?> Query.string "search")
        , map NewRecipe (s "editor")
        , map EditRecipe (s "editor" </> Slug.urlParser)
        , map Login (s "login")
        ]


href : Route -> Attribute msg
href targetRoute =
    Attr.href (toString targetRoute)


fromUrl : Url -> Maybe Route
fromUrl url =
    Parser.parse parser url


replaceUrl : Nav.Key -> Route -> Cmd msg
replaceUrl key route =
    Nav.replaceUrl key (toString route)


pushUrl : Nav.Key -> Route -> Cmd msg
pushUrl key route =
    Nav.pushUrl key (toString route)


toString : Route -> String
toString page =
    let
        pieces =
            case page of
                Recipe slug ->
                    [ "recipe", Url.percentEncode <| Slug.toString slug ]

                RecipeList (Just query) ->
                    [ Url.Builder.toQuery [ Url.Builder.string "search" query ] ]

                RecipeList Nothing ->
                    []

                NewRecipe ->
                    [ "editor" ]

                EditRecipe slug ->
                    [ "editor", Url.percentEncode <| Slug.toString slug ]

                Login ->
                    [ "login" ]
    in
    "/" ++ String.join "/" pieces
