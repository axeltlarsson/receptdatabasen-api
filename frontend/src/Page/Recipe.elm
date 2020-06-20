module Page.Recipe exposing (Model, Msg(..), init, toSession, update, view)

import Dict exposing (Dict)
import Element
    exposing
        ( Element
        , alignBottom
        , alignLeft
        , alignRight
        , alignTop
        , centerX
        , centerY
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
import Element.Region as Region
import Html
import Html.Attributes
import Http
import Json.Decode as Decoder exposing (Decoder, list)
import Loading
import Page.Recipe.Markdown as Markdown
import Palette
import Recipe exposing (Full, Metadata, Recipe, contents, fullDecoder, metadata)
import Recipe.Slug as Slug exposing (Slug)
import Route
import Session exposing (Session)
import Url exposing (Url)
import Url.Builder



--- MODEL


type alias Model =
    { session : Session, recipe : Status (Recipe Full), checkboxStatus : Dict Int Bool }


type Status recipe
    = Loading
    | Loaded recipe
    | Failed Recipe.ServerError


init : Session -> Slug -> ( Model, Cmd Msg )
init session slug =
    case Session.recipe session slug of
        Just recipe ->
            ( { recipe = Loaded recipe
              , session = session
              , checkboxStatus = Dict.empty
              }
            , Cmd.none
            )

        Nothing ->
            ( { recipe = Loading
              , session = session
              , checkboxStatus = Dict.empty
              }
            , Recipe.fetch slug LoadedRecipe
            )



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
                    , content = Loading.error "Kunde ej ladda in recept" (Recipe.serverErrorToString err)
                    }

                Loaded recipe ->
                    let
                        { title } =
                            Recipe.metadata recipe
                    in
                    { title = Slug.toString title
                    , content = viewRecipe recipe model.checkboxStatus (Session.device model.session)
                    }
    in
    { title = ui.title
    , content =
        column [ Region.mainContent, width fill ] [ ui.content ]
    }


phoneLayout : Element.Device -> Bool
phoneLayout ({ class, orientation } as device) =
    case ( class, orientation ) of
        ( Element.Phone, Element.Portrait ) ->
            True

        _ ->
            False


tabletOrSmaller : Element.Device -> Bool
tabletOrSmaller ({ class, orientation } as device) =
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


viewRecipe : Recipe Full -> Dict Int Bool -> Element.Device -> Element Msg
viewRecipe recipe checkboxStatus device =
    let
        { title, description, id, images, createdAt, updatedAt } =
            Recipe.metadata recipe

        image =
            List.head images

        { portions, ingredients, instructions, tags } =
            Recipe.contents recipe

        responsiveLayout =
            if phoneLayout device then
                column [ width fill, spacing 30 ]

            else
                row [ width fill, spacing 60 ]
    in
    column [ width fill, spacing 30 ]
        [ viewHeader (Slug.toString title) tags description image device
        , column [ width fill, padding <| paddingPx device, spacing 20 ]
            [ responsiveLayout
                [ viewInstructions instructions checkboxStatus
                , viewIngredients ingredients portions
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
            image |> Maybe.map (\p -> "http://localhost:8080/images/sig/1600/" ++ p) |> Maybe.withDefault lemonadeUrl
    in
    if tabletOrSmaller device then
        column [ width fill, height <| Element.px 600 ]
            [ Element.el
                [ width fill
                , height fill
                , Background.image imageUrl
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
            , el [ spacing 0, padding 0, width fill, height fill, Background.image imageUrl ] Element.none
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
    description
        |> Maybe.map (text >> List.singleton >> paragraph [ Font.light, width fill ])
        |> Maybe.withDefault Element.none


viewInstructions : String -> Dict Int Bool -> Element Msg
viewInstructions instructions checkboxStatus =
    column [ alignTop, alignLeft, width fill, Font.color Palette.nearBlack ]
        [ el [ Font.size Palette.xLarge ] (text "Gör så här")
        , el [ paddingXY 0 20 ] (paragraph [] [ viewMarkdown instructions checkboxStatus ])
        ]


viewIngredients : String -> Int -> Element Msg
viewIngredients ingredients portions =
    column [ alignTop, width fill ]
        [ column []
            [ el [ Font.size Palette.xLarge ] (text "Ingredienser")
            , paragraph [ paddingEach { edges | top = 10, bottom = 20 } ] [ text <| String.fromInt portions, text " portioner" ]
            , column [] [ viewMarkdown ingredients Dict.empty ]
            ]
        ]


viewMarkdown : String -> Dict Int Bool -> Element Msg
viewMarkdown instructions checkboxStatus =
    case Markdown.render instructions checkboxStatus ClickedCheckbox of
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


debug : Element.Attribute Msg
debug =
    Element.explain Debug.todo


pancakeImgUrl : String
pancakeImgUrl =
    "https://assets.icanet.se/q_auto,f_auto/imagevaultfiles/id_185874/cf_259/pannkakstarta-med-choklad-och-nutella-724305-stor.jpg"


lemonadeUrl : String
lemonadeUrl =
    "https://assets.icanet.se/q_auto,f_auto/imagevaultfiles/id_214425/cf_259/rabarberlemonad-721978.jpg"


iceCoffeeUrl : String
iceCoffeeUrl =
    "https://assets.icanet.se/q_auto,f_auto/imagevaultfiles/id_214221/cf_259/iskaffe-med-kondenserad-mjolk-och-choklad-726741.jpg"


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
    = LoadedRecipe (Result Recipe.ServerError (Recipe Full))
    | ClickedCheckbox Int Bool
    | ClickedDelete
    | ClickedEdit
    | Deleted (Result Http.Error ())


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedRecipe (Ok recipe) ->
            ( { model | recipe = Loaded recipe, session = Session.addRecipe recipe model.session }, Cmd.none )

        LoadedRecipe (Err error) ->
            ( { model | recipe = Failed error }, Cmd.none )

        ClickedCheckbox idx checked ->
            ( { model | checkboxStatus = Dict.update idx (\x -> Just checked) model.checkboxStatus }, Cmd.none )

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

        Deleted (Ok _) ->
            ( model
            , Route.RecipeList
                |> Route.replaceUrl (Session.navKey model.session)
            )

        Deleted (Err error) ->
            ( { model | recipe = Failed (Recipe.serverErrorFromHttp error) }, Cmd.none )



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
