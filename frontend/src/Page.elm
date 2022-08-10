module Page exposing (Page(..), view, viewWithoutHeader)

import Browser exposing (Document)
import Element exposing (Element, alignLeft, alignTop, centerX, column, el, fill, height, link, maximum, padding, paddingEach, paddingXY, row, spacing, spacingXY, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Lazy exposing (lazy2)
import Element.Region as Region
import FeatherIcons
import Palette exposing (edges)
import Route exposing (Route)


{-| Determines which navbar link will be rendered as active
-}
type Page
    = Recipe
    | RecipeList
    | Editor
    | Login
    | Other


{-| Takes a page's Html and frames it with header and footer.
-}
view : Page -> { title : String, stickyContent : Element msg, content : Element msg } -> Document msg
view page { title, stickyContent, content } =
    { title = title ++ " | Receptdatabasen"
    , body =
        [ Element.layout
            [ Font.family [ Font.typeface "Metropolis" ]
            , Font.color Palette.nearBlack
            , Font.size Palette.normal
            , width fill
            , Element.inFront (lazy2 viewHeader page stickyContent)
            ]
            (column [ Element.paddingXY 0 (headerHeight + 10), width (fill |> maximum maxPageWidth), Element.centerX ]
                [ content ]
            )
        ]
    }


viewWithoutHeader : Page -> { title : String, content : Element msg } -> Document msg
viewWithoutHeader _ { title, content } =
    { title = title ++ " | Receptdatabasen"
    , body =
        [ Element.layout
            [ Font.family [ Font.typeface "Metropolis" ]
            , Font.color Palette.nearBlack
            , Font.size Palette.normal
            , width fill
            ]
            (column [ Element.paddingXY 0 (headerHeight + 10), width (fill |> maximum maxPageWidth), Element.centerX ]
                [ content ]
            )
        ]
    }


headerHeight =
    58


maxPageWidth =
    1440


viewHeader : Page -> Element msg -> Element msg
viewHeader page stickyContent =
    row
        [ width fill
        , Border.glow Palette.lightGrey 0.5
        ]
        [ row
            [ Region.navigation
            , alignTop
            , centerX
            , width (fill |> maximum maxPageWidth)
            , height (Element.px headerHeight)
            , paddingXY 10 0
            , Element.behindContent
                (el
                    [ Element.alpha 0.9
                    , Background.color <| Palette.blush
                    , width fill
                    , height fill
                    ]
                    Element.none
                )
            ]
            [ viewMenu page, stickyContent ]
        ]


debug =
    Element.explain Debug.todo


viewMenu : Page -> Element msg
viewMenu page =
    let
        linkTo route label =
            navbarLink page
                route
                (el [ Font.light ] label)
    in
    row [ alignLeft, spacingXY 20 0 ]
        [ row [] [ linkTo (Route.RecipeList Nothing) logo ]
        , linkTo Route.NewRecipe (row [ spacing 10 ] [ wrapIcon FeatherIcons.plusCircle, text "Nytt recept" ])
        ]


wrapIcon icon =
    el [ Element.centerX ]
        (icon |> FeatherIcons.withSize 26 |> FeatherIcons.withStrokeWidth 1 |> FeatherIcons.toHtml [] |> Element.html)


logo : Element msg
logo =
    row [ height fill, paddingXY 10 0, spacing 10 ]
        [ Element.image [ height (Element.px (headerHeight - 20)) ] { src = "%PUBLIC_URL%/logo.png", description = "home" }
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
            [ Element.mouseOver [ Element.alpha 0.5, Background.color Palette.mulberry, Font.color Palette.white ]
            , Font.size Palette.large
            , height fill
            , paddingEach { edges | top = 15, bottom = 15, right = 15 }
            ]
            activeAttrs
        )
        { url = Route.toString route
        , label = linkContent
        }


isActive : Page -> Route -> Bool
isActive page route =
    case ( page, route ) of
        ( RecipeList, Route.RecipeList _ ) ->
            True

        ( Recipe, Route.Recipe _ ) ->
            True

        ( Editor, Route.NewRecipe ) ->
            True

        _ ->
            False
