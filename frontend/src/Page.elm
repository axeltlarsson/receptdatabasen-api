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
            , Element.inFront (viewHeader page)
            ]
            (column [ Element.paddingXY 0 headerHeight, width (fill |> Element.maximum 1440), Element.centerX ]
                [ content ]
            )
        ]
    }


headerHeight =
    58


viewHeader : Page -> Element msg
viewHeader page =
    row
        [ Region.navigation
        , alignTop
        , width fill
        , height (Element.px headerHeight)
        , Border.glow Palette.lightGrey 0.5
        , Element.behindContent
            (el
                [ Element.alpha 0.95
                , Background.color <| Palette.white
                , width fill
                , height fill
                ]
                Element.none
            )
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
        [ linkTo Route.RecipeList "ALLA RECEPT"
        , linkTo Route.NewRecipe "NYTT RECEPT"
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
