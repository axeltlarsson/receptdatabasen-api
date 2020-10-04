module Route exposing (Route(..), fromUrl, href, pushUrl, replaceUrl, toString)

import Browser.Navigation as Nav
import Html exposing (Attribute)
import Html.Attributes as Attr
import Recipe.Slug as Slug exposing (Slug)
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), (<?>), Parser, int, map, oneOf, s, string)
import Url.Parser.Query as Query



-- ROUTING


type Route
    = Recipe Slug
    | RecipeList (Maybe String)
    | NewRecipe
    | EditRecipe Slug


parser : Parser (Route -> a) a
parser =
    oneOf
        [ map Recipe (s "recipe" </> Slug.urlParser)
        , map RecipeList (Parser.top <?> Query.string "search")
        , map NewRecipe (s "editor")
        , map EditRecipe (s "editor" </> Slug.urlParser)
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

                RecipeList maybeQuery ->
                    [] ++ [ maybeQuery |> Maybe.map ((++) "?search=") |> Maybe.withDefault "" ]

                NewRecipe ->
                    [ "editor" ]

                EditRecipe slug ->
                    [ "editor", Url.percentEncode <| Slug.toString slug ]
    in
    "/" ++ String.join "/" pieces
