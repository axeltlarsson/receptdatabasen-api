module Page.Recipe exposing (Model, Msg(..), init, toSession, update, view)

import Api
import Browser.Dom as Dom
import Dict exposing (Dict)
import Element
    exposing
        ( Element
        , alignBottom
        , alignLeft
        , alignTop
        , column
        , el
        , fill
        , height
        , padding
        , paddingEach
        , paddingXY
        , paragraph
        , rgb255
        , rgba255
        , row
        , spacing
        , text
        , width
        , wrappedRow
        )
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Element.Lazy exposing (lazy2, lazy3, lazy5)
import Element.Region as Region
import FeatherIcons
import Html.Attributes
import Loading
import Page.Recipe.Ingredient as Ingredient
import Page.Recipe.Markdown as Markdown
import Palette
import Recipe exposing (Full, Recipe)
import Recipe.Slug as Slug exposing (Slug)
import Route
import Session exposing (Session)
import Task



--- MODEL


type alias Model =
    { session : Session, recipe : Status (Recipe Full), checkboxStatus : Dict Int Bool, scaledPortions : Int }


type Status recipe
    = Loading
    | Loaded recipe
    | Failed Api.ServerError


init : Session -> Slug -> ( Model, Cmd Msg )
init session slug =
    case Session.recipe session slug of
        Just recipe ->
            ( { recipe = Loaded recipe
              , session = session
              , checkboxStatus = Dict.empty
              , scaledPortions = recipe |> Recipe.contents |> .portions
              }
            , resetViewport
            )

        Nothing ->
            ( { recipe = Loading
              , session = session
              , checkboxStatus = Dict.empty
              , scaledPortions = 0
              }
            , Cmd.batch [ Recipe.fetch slug LoadedRecipe, resetViewport ]
            )


resetViewport : Cmd Msg
resetViewport =
    Task.perform (\_ -> SetViewport) (Dom.setViewport 0 0)



-- VIEW


view : Model -> { title : String, content : Element Msg }
view model =
    let
        ui =
            case model.recipe of
                Loading ->
                    { title = "Laddar..."
                    , content = Element.html Loading.animation
                    }

                Failed err ->
                    { title = "Kunde ej hämta recept"
                    , content = Api.viewServerError "" err
                    }

                Loaded recipe ->
                    let
                        { title } =
                            Recipe.metadata recipe
                    in
                    { title = Slug.toString title
                    , content = viewRecipe recipe model.checkboxStatus model.scaledPortions (Session.device model.session)
                    }
    in
    { title = ui.title
    , content =
        column [ Region.mainContent, width fill ] [ ui.content ]
    }


phoneLayout : Element.Device -> Bool
phoneLayout { class, orientation } =
    case ( class, orientation ) of
        ( Element.Phone, Element.Portrait ) ->
            True

        _ ->
            False


tabletOrSmaller : Element.Device -> Bool
tabletOrSmaller { class, orientation } =
    case ( class, orientation ) of
        ( Element.Phone, Element.Portrait ) ->
            True

        ( Element.Tablet, Element.Portrait ) ->
            True

        _ ->
            False


paddingPx : Element.Device -> Int
paddingPx device =
    if phoneLayout device then
        10

    else
        30


viewRecipe : Recipe Full -> Dict Int Bool -> Int -> Element.Device -> Element Msg
viewRecipe recipe checkboxStatus scaledPortions device =
    let
        { title, description, images } =
            Recipe.metadata recipe

        image =
            List.head images |> Maybe.map .url

        { portions, ingredients, instructions, tags } =
            Recipe.contents recipe

        responsiveLayout =
            if phoneLayout device then
                column [ width fill, spacing 30 ]

            else
                row [ width fill, spacing 60 ]
    in
    column [ width fill, spacing 30 ]
        [ lazy5 viewHeader (Slug.toString title) tags description image device
        , lazy2 column
            [ width fill, padding <| paddingPx device, spacing 20 ]
            [ responsiveLayout
                [ lazy2 viewInstructions instructions checkboxStatus
                , lazy3 viewIngredients ingredients scaledPortions portions
                ]
            , row [ spacing 20 ]
                [ viewEditButton
                , viewDeleteButton
                ]
            ]
        ]


viewHeader : String -> List String -> Maybe String -> Maybe String -> Element.Device -> Element Msg
viewHeader title tags description image device =
    let
        imageUrl =
            image |> Maybe.map (\p -> "/images/sig/1600/" ++ p)

        background =
            imageUrl
                |> Maybe.map Background.image
                |> Maybe.withDefault (Background.color Palette.white)
    in
    if tabletOrSmaller device then
        column [ width fill, height <| Element.px 600 ]
            [ Element.el
                [ width fill
                , height fill
                , background
                ]
                (column
                    [ alignBottom
                    , Element.behindContent <|
                        el [ width fill, height fill, floorFade ] Element.none
                    , padding <| paddingPx device
                    , spacing 20
                    , width fill
                    ]
                    [ viewTitle title
                    ]
                )
            , column
                [ paddingXY (paddingPx device) 20
                , width (fill |> Element.maximum 800)
                , spacing 20
                ]
                [ viewTags tags
                , viewDescription description
                ]
            ]

    else
        row [ width fill, Border.glow Palette.lightGrey 0.5 ]
            [ column [ height (fill |> Element.minimum 400), width fill, alignBottom, spacing 20, paddingXY (paddingPx device) 20 ]
                [ paragraph [ Font.size Palette.xxLarge, Font.heavy ] [ text title ]
                , viewTags tags
                , viewDescription description
                ]
            , el [ spacing 0, padding 0, width fill, height fill, background ] Element.none
            ]


floorFade : Element.Attribute msg
floorFade =
    Background.gradient
        { angle = pi -- down
        , steps =
            [ rgba255 0 0 0 0
            , rgba255 0 0 0 0.2
            , rgba255 0 0 0 0.2
            ]
        }


viewTitle : String -> Element Msg
viewTitle title =
    paragraph
        [ Font.size Palette.xxLarge
        , Font.color Palette.white
        , Palette.textShadow
        , width (fill |> Element.maximum 800)
        ]
        [ text title ]


viewTags : List String -> Element Msg
viewTags tags =
    let
        viewTag tag =
            el
                [ Background.color Palette.grey
                , Font.color Palette.white
                , Border.rounded 2
                , padding 10
                ]
                (text tag)
    in
    wrappedRow
        [ spacing 10 ]
        (List.map viewTag tags)


viewDescription : Maybe String -> Element Msg
viewDescription description =
    let
        overflowWrap =
            Element.htmlAttribute <| Html.Attributes.style "overflow-wrap" "anywhere"
    in
    description
        |> Maybe.map
            (String.split "\n"
                >> List.map text
                >> List.map List.singleton
                >> List.map
                    (paragraph
                        [ Font.light, width fill, overflowWrap ]
                    )
                >> column [ spacing 10 ]
            )
        |> Maybe.withDefault Element.none


viewInstructions : String -> Dict Int Bool -> Element Msg
viewInstructions instructions checkboxStatus =
    column [ alignTop, alignLeft, width fill, Font.color Palette.nearBlack ]
        [ el [ Font.size Palette.xLarge ] (text "Gör så här")
        , el [ paddingXY 0 20 ] (paragraph [] [ viewMarkdown 1 True instructions checkboxStatus ])
        ]


viewIngredients : String -> Int -> Int -> Element Msg
viewIngredients ingredients scaledPortions originalPortions =
    column [ alignTop, width fill ]
        [ column []
            [ el [ Font.size Palette.xLarge ] (text "Ingredienser")
            , viewPortions scaledPortions originalPortions
            , column [] [ viewMarkdown (toFloat scaledPortions / toFloat originalPortions) False ingredients Dict.empty ]
            ]
        ]


viewPortions : Int -> Int -> Element Msg
viewPortions scaledPortions portions =
    let
        wrapIcon icon =
            el [ Element.centerX ]
                (icon |> FeatherIcons.withSize 26 |> FeatherIcons.withStrokeWidth 1 |> FeatherIcons.toHtml [] |> Element.html)

        decrementButton =
            Input.button
                [ Border.rounded 20 ]
                { onPress = Just DecrementPortions
                , label = wrapIcon FeatherIcons.minusCircle
                }

        incrementButton =
            Input.button
                [ Border.rounded 20 ]
                { onPress = Just IncrementPortions
                , label = wrapIcon FeatherIcons.plusCircle
                }

        scaledAttrs =
            if portions /= scaledPortions then
                [ Font.underline
                , Font.bold
                ]

            else
                []

        portionString =
            if scaledPortions > 1 then
                " portioner"

            else
                " portion"
    in
    row [ paddingEach { edges | top = 10, bottom = 10 }, spacing 10 ]
        [ decrementButton
        , row [ Events.onClick ResetPortions, Element.pointer, Element.centerX, width (Element.px 115) ]
            [ el (List.append [ Element.centerX ] scaledAttrs) <| text (String.fromInt scaledPortions ++ portionString)
            ]
        , incrementButton
        ]


portionsScaler : Float -> String -> String
portionsScaler scale str =
    str
        |> Ingredient.fromString
        |> Result.map (Ingredient.scale scale)
        |> Result.map Ingredient.toString
        |> Result.withDefault str


viewMarkdown : Float -> Bool -> String -> Dict Int Bool -> Element Msg
viewMarkdown scale alwaysTaskList instructions checkboxStatus =
    let
        rendered =
            if alwaysTaskList then
                Markdown.renderWithTaskList instructions checkboxStatus ClickedCheckbox

            else
                Markdown.renderWithMapping instructions (portionsScaler scale) ClickedCheckbox
    in
    case rendered of
        Ok md ->
            column [ width fill, spacing 10, Font.light ]
                md

        Err err ->
            column [ width fill, Font.light ]
                [ text err ]


edges =
    { top = 0
    , right = 0
    , bottom = 0
    , left = 0
    }


viewDeleteButton : Element Msg
viewDeleteButton =
    Input.button
        [ Background.color (rgb255 255 0 0), Border.rounded 3, padding 10, Font.color Palette.white ]
        { onPress = Just ClickedDelete
        , label = text "Radera"
        }


viewEditButton : Element Msg
viewEditButton =
    Input.button
        [ Background.color (rgb255 255 127 0), Border.rounded 3, padding 10, Font.color Palette.white ]
        { onPress = Just ClickedEdit
        , label = text "Ändra"
        }



-- UPDATE


type Msg
    = LoadedRecipe (Result Api.ServerError (Recipe Full))
    | ClickedCheckbox Int Bool
    | ClickedDelete
    | ClickedEdit
    | DecrementPortions
    | IncrementPortions
    | ResetPortions
    | Deleted (Result Api.ServerError ())
    | SetViewport


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedRecipe (Ok recipe) ->
            ( { model
                | recipe = Loaded recipe
                , session = Session.addRecipe recipe model.session
                , scaledPortions =
                    recipe
                        |> Recipe.contents
                        |> .portions
              }
            , Cmd.none
            )

        LoadedRecipe (Err error) ->
            case error of
                Api.Unauthorized ->
                    ( model, Route.pushUrl (Session.navKey (toSession model)) Route.Login )

                _ ->
                    ( { model | recipe = Failed error }, Cmd.none )

        ClickedCheckbox idx checked ->
            ( { model | checkboxStatus = Dict.update idx (\_ -> Just checked) model.checkboxStatus }, Cmd.none )

        ClickedDelete ->
            case model.recipe of
                Loaded recipe ->
                    ( model, Recipe.delete (Recipe.slug recipe) Deleted )

                _ ->
                    ( model, Cmd.none )

        ClickedEdit ->
            case model.recipe of
                Loaded recipe ->
                    let
                        newRoute =
                            Route.EditRecipe (Recipe.slug recipe)
                    in
                    ( model, Route.pushUrl (Session.navKey model.session) newRoute )

                _ ->
                    ( model, Cmd.none )

        DecrementPortions ->
            ( { model | scaledPortions = max (model.scaledPortions - 1) 1 }, Cmd.none )

        IncrementPortions ->
            ( { model | scaledPortions = min (model.scaledPortions + 1) 100 }, Cmd.none )

        ResetPortions ->
            case model.recipe of
                Loaded recipe ->
                    let
                        portions =
                            recipe |> Recipe.contents |> .portions
                    in
                    ( { model | scaledPortions = portions }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Deleted (Ok _) ->
            ( model
            , Route.RecipeList Nothing
                |> Route.replaceUrl (Session.navKey model.session)
            )

        Deleted (Err error) ->
            ( { model | recipe = Failed error }, Cmd.none )

        SetViewport ->
            ( model, Cmd.none )



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
