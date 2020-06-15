module Page exposing (Page(..), view)

import Browser exposing (Document)
import Element exposing (Element, alignBottom, alignLeft, alignTop, centerX, column, el, fill, height, link, padding, row, spacing, spacingXY, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Region as Region
import Palette
import Route exposing (Route)


{-| Determines which navbar link will be rendered as active
-}
type Page
    = Recipe
    | RecipeList
    | Editor
    | Other


debug : Element.Attribute msg
debug =
    Element.explain Debug.todo


{-| Takes a page's Html and frames it with header and footer.
-}
view : Page -> { title : String, content : Element msg } -> Document msg
view page { title, content } =
    { title = title ++ " | Receptdatabasen"
    , body =
        [ Element.layout
            [ Font.family [ Font.typeface "Metropolis" ]
            , Font.color Palette.nearBlack
            , Font.size Palette.normal
            , width fill
            ]
            (column [ width (fill |> Element.maximum 1440), Element.centerX ]
                [ viewHeader page
                , content
                ]
            )
        ]
    }


viewHeader : Page -> Element msg
viewHeader page =
    row
        [ Region.navigation
        , alignTop
        , width fill
        , Border.glow Palette.lightGrey 0.5
        ]
        [ viewMenu page ]


viewMenu : Page -> Element msg
viewMenu page =
    let
        linkTo route title =
            navbarLink page
                route
                (el
                    [ Font.light ]
                    (text title)
                )
    in
    row [ alignLeft, spacingXY 20 0 ]
        [ linkTo Route.NewRecipe "Nytt recept"
        , linkTo Route.RecipeList "Alla recept"
        ]


navbarLink : Page -> Route -> Element msg -> Element msg
navbarLink page route linkContent =
    let
        activeAttrs =
            if isActive page route then
                [ Font.underline
                ]

            else
                []
    in
    link
        (List.append
            [ Element.mouseOver [ Element.alpha 0.5, Background.color Palette.grey, Font.color Palette.white ]
            , Font.size Palette.large
            , height fill
            , padding 15
            ]
            activeAttrs
        )
        { url = Route.toString route
        , label = linkContent
        }


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
