module Route exposing (Route(..), fromUrl, href, replaceUrl)

import Browser.Navigation as Nav
import Html exposing (Attribute)
import Html.Attributes as Attr
import Recipe.Slug as Slug exposing (Slug)
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser, int, map, oneOf, s, string)



-- ROUTING


type Route
    = Recipe Slug
    | RecipeList
    | NewRecipe
    | EditRecipe Slug


parser : Parser (Route -> a) a
parser =
    oneOf
        [ map Recipe (s "recipe" </> Slug.urlParser)
        , map RecipeList Parser.top
        , map NewRecipe (s "editor")
        , map EditRecipe (s "editor" </> Slug.urlParser)
        ]



-- PUBLIC HELPERS


href : Route -> Attribute msg
href targetRoute =
    Attr.href (routeToString targetRoute)


fromUrl : Url -> Maybe Route
fromUrl url =
    Parser.parse parser url


replaceUrl : Nav.Key -> Route -> Cmd msg
replaceUrl key route =
    Nav.replaceUrl key (routeToString route)



--INTERNAL


routeToString : Route -> String
routeToString page =
    let
        pieces =
            case page of
                Recipe slug ->
                    [ "recipe", Url.percentEncode (Slug.toString slug) ]

                RecipeList ->
                    []

                NewRecipe ->
                    [ "editor" ]

                EditRecipe slug ->
                    [ "editor", Url.percentEncode (Slug.toString slug) ]
    in
    "/" ++ String.join "/" pieces
