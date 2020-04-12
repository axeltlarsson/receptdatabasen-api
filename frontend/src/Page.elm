module Page exposing (Page(..), view)

import Browser exposing (Document)
import Html exposing (..)
import Html.Attributes exposing (class, classList, href, style)
import Route exposing (Route)


{-| Determins which navbar link will be rendered as active
-}
type Page
    = Recipe
    | RecipeList
    | Editor
    | Other


{-| Takes a page's Html and frames it with header and footer.
-}
view : Page -> { title : String, content : Html msg } -> Document msg
view page { title, content } =
    { title = title ++ " | Receptdatabasen"
    , body = viewHeader page :: [ content ]
    }


viewHeader : Page -> Html msg
viewHeader page =
    nav [ class "navbar tab-container tabs-depth tabs-fill" ]
        [ ul [ class "nav" ] <| viewMenu page
        ]


viewMenu : Page -> List (Html msg)
viewMenu page =
    let
        linkTo =
            navbarLink page
    in
    [ linkTo Route.NewRecipe [ text "Nytt recept" ]
    , linkTo Route.RecipeList [ text "Alla recept" ]
    ]


navbarLink : Page -> Route -> List (Html msg) -> Html msg
navbarLink page route linkContent =
    li [ classList [ ( "nav-item", True ), ( "selected", isActive page route ) ] ]
        [ a [ class "nav-link", Route.href route ] linkContent ]


isActive : Page -> Route -> Bool
isActive page route =
    case ( page, route ) of
        ( RecipeList, Route.RecipeList ) ->
            True

        ( Recipe, Route.Recipe _ ) ->
            True

        ( Editor, Route.NewRecipe ) ->
            True

        _ ->
            False
