module Route exposing (Route(..), fromUrl, pushUrl, replaceUrl, toString)

import Browser.Navigation as Nav
import Recipe.Slug as Slug exposing (Slug(..))
import Url exposing (Url)
import Url.Builder
import Url.Parser as Parser exposing ((</>), (<?>), Parser, map, oneOf, query, s)
import Url.Parser.Query as Query



-- ROUTING


type Route
    = Recipe Slug
    | RecipeList (Maybe String)
    | NewRecipe
    | EditRecipe Slug
    | Login (Maybe Slug)
    | MyProfile


parser : Parser (Route -> a) a
parser =
    oneOf
        [ map Recipe (s "recipe" </> Slug.urlParser)
        , map RecipeList (Parser.top <?> Query.string "search")
        , map NewRecipe (s "editor")
        , map EditRecipe (s "editor" </> Slug.urlParser)
        , map (\maybeStr -> Login (Maybe.map Slug.Slug maybeStr))
            (s "login" <?> Query.string "redirect")
        , map MyProfile (s "my-profile")
        ]


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
    case page of
        Recipe slug ->
            Url.Builder.absolute [ "recipe", Url.percentEncode (Slug.toString slug) ] []

        RecipeList (Just query) ->
            Url.Builder.absolute [] [ Url.Builder.string "search" query ]

        RecipeList Nothing ->
            Url.Builder.absolute [] []

        NewRecipe ->
            Url.Builder.absolute [ "editor" ] []

        EditRecipe slug ->
            Url.Builder.absolute [ "editor", Slug.toString slug ] []

        Login (Just slug) ->
            Url.Builder.absolute [ "login" ] [ Url.Builder.string "redirect" <| Slug.toString slug ]

        Login Nothing ->
            Url.Builder.absolute [ "login" ] []

        MyProfile ->
            Url.Builder.absolute [ "my-profile" ] []
