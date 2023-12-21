module Page exposing (Page(..), view, viewWithoutHeader)

import Browser exposing (Document)
import Element
    exposing
        ( Element
        , alignLeft
        , alignTop
        , centerX
        , column
        , el
        , fill
        , height
        , link
        , maximum
        , padding
        , paddingXY
        , row
        , spacing
        , spacingXY
        , text
        , width
        )
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Lazy exposing (lazy3)
import Element.Region as Region
import FeatherIcons
import Palette
import Route exposing (Route)
import Session exposing (Session)


{-| Determines which navbar link will be rendered as active
-}
type Page
    = Recipe
    | RecipeList
    | Editor
    | Login
    | MyProfile
    | Other


{-| Takes a page's Html and frames it with header and footer.
-}
view : Page -> Session -> { title : String, stickyContent : Element msg, content : Element msg } -> Document msg
view page session { title, stickyContent, content } =
    let
        device =
            Session.device session
    in
    { title = title ++ " | Receptdatabasen"
    , body =
        [ Element.layout
            [ Font.family [ Font.typeface "Metropolis" ]
            , Font.color Palette.nearBlack
            , Font.size Palette.normal
            , width fill
            , Element.inFront (lazy3 viewHeader page device stickyContent)
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


headerHeight : Int
headerHeight =
    58


maxPageWidth : Int
maxPageWidth =
    1440


wrapIcon : FeatherIcons.Icon -> Element msg
wrapIcon icon =
    el [ Element.centerX ]
        (icon |> FeatherIcons.withSize 26 |> FeatherIcons.withStrokeWidth 1 |> FeatherIcons.toHtml [] |> Element.html)


viewHeader : Page -> Element.Device -> Element msg -> Element msg
viewHeader page device stickyContent =
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
                    [ Element.alpha 0.95
                    , Background.color <| Palette.white
                    , width fill
                    , height fill
                    ]
                    Element.none
                )
            ]
            [ viewMenu page device, stickyContent ]
        ]


phoneLayout : Element.Device -> Bool
phoneLayout { class, orientation } =
    case ( class, orientation ) of
        ( Element.Phone, Element.Portrait ) ->
            True

        _ ->
            False


viewMenu : Page -> Element.Device -> Element msg
viewMenu page device =
    let
        linkTo route icon label =
            navbarLink page
                route
                (row [ spacing 10, Font.light ]
                    [ wrapIcon icon, showLabel label ]
                )

        showLabel label =
            label |> Maybe.map text |> Maybe.withDefault Element.none
    in
    if phoneLayout device then
        row [ width fill, Element.spaceEvenly ]
            [ linkTo (Route.RecipeList Nothing) FeatherIcons.home <| Nothing
            , linkTo Route.NewRecipe FeatherIcons.plus <| Nothing
            , linkTo Route.MyProfile FeatherIcons.user <| Nothing
            ]

    else
        row [ alignLeft ]
            [ linkTo (Route.RecipeList Nothing) FeatherIcons.home <| Just "Alla recept"
            , linkTo Route.NewRecipe FeatherIcons.plus <| Just "Nytt recept"
            , linkTo Route.MyProfile FeatherIcons.user <| Just "Min profil"
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
        ( RecipeList, Route.RecipeList _ ) ->
            True

        ( Recipe, Route.Recipe _ ) ->
            True

        ( Editor, Route.NewRecipe ) ->
            True

        ( MyProfile, Route.MyProfile ) ->
            True

        _ ->
            False
