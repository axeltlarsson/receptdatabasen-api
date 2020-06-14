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
        )
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Html
import Html.Attributes
import Http
import Json.Decode as Decoder exposing (Decoder, list)
import Loading
import Markdown.Block as Block exposing (Block, Inline, ListItem(..), Task(..))
import Markdown.Html
import Markdown.Parser
import Markdown.Renderer
import Palette
import Recipe exposing (Full, Metadata, Recipe, contents, fullDecoder, metadata)
import Recipe.Slug as Slug exposing (Slug)
import Route
import Session exposing (Session)
import Url exposing (Url)
import Url.Builder



--- MODEL


type alias Model =
    { session : Session, recipe : Status (Recipe Full) }


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
              }
            , Cmd.none
            )

        Nothing ->
            ( { recipe = Loading
              , session = session
              }
            , Recipe.fetch slug LoadedRecipe
            )



-- VIEW


view : Model -> { title : String, content : Element Msg }
view model =
    let
        ui =
            viewUi model
    in
    { title = ui.title
    , content =
        column [ Region.mainContent, width fill ]
            [ ui.content
            ]
    }


viewUi : Model -> { title : String, content : Element Msg }
viewUi model =
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
            , content = viewRecipe recipe (Session.device model.session)
            }


phoneLayout : Element.Device -> Bool
phoneLayout ({ class, orientation } as device) =
    case ( class, orientation ) of
        ( Element.Phone, Element.Portrait ) ->
            True

        _ ->
            False


paddingPx : Element.Device -> Int
paddingPx device =
    if phoneLayout device then
        10

    else
        30


viewRecipe : Recipe Full -> Element.Device -> Element Msg
viewRecipe recipe device =
    let
        { title, description, id, createdAt } =
            Recipe.metadata recipe

        { portions, ingredients, instructions } =
            Recipe.contents recipe

        responsiveLayout =
            if phoneLayout device then
                column [ width fill, spacing 30 ]

            else
                row [ width fill, spacing 60 ]
    in
    column [ width fill, spacing 30 ]
        [ viewHeader (Slug.toString title) description device
        , column [ width fill, padding <| paddingPx device, spacing 20 ]
            [ responsiveLayout
                [ viewInstructions instructions
                , viewIngredients ingredients portions
                ]
            , row [ spacing 20 ]
                [ viewEditButton
                , viewDeleteButton
                ]
            ]
        ]


viewHeader : String -> Maybe String -> Element.Device -> Element Msg
viewHeader title description device =
    column [ width fill, height <| Element.px 400 ]
        [ Element.el
            [ width fill
            , height fill
            , Background.image iceCoffeeUrl
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
        , viewDescription description (paddingPx device)
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
        [ Font.size 48
        , Font.color Palette.white
        , Palette.textShadow
        , width
            (fill
                |> Element.maximum 800
            )
        ]
        [ text title ]


viewDescription : Maybe String -> Int -> Element Msg
viewDescription description pad =
    el
        [ paddingXY pad 20
        , width
            (fill
                |> Element.maximum 800
            )
        ]
        (paragraph [ Font.light, width fill ] [ text <| Maybe.withDefault "" description ])


viewInstructions : String -> Element Msg
viewInstructions instructions =
    column [ alignTop, alignLeft, width fill, Font.color Palette.nearBlack ]
        [ el [ Font.size 32 ] (text "Gör så här")
        , el [ paddingXY 0 10 ] (paragraph [] [ viewMarkdown instructions ])
        ]


viewIngredients : String -> Int -> Element Msg
viewIngredients ingredients portions =
    column [ alignTop, width fill ]
        [ column []
            -- TODO: centerX ^ a good idea?
            [ el [ Font.size 32 ] (text "Ingredienser")
            , paragraph [ paddingXY 0 20 ] [ text <| String.fromInt portions, text " portioner" ]
            , column [] [ viewMarkdown ingredients ]
            ]
        ]


viewMarkdown : String -> Element Msg
viewMarkdown instructions =
    case renderMarkdown instructions of
        Ok md ->
            column [ width fill, spacing 10, Font.light ]
                md

        Err err ->
            column [ width fill, Font.light ]
                [ text err ]


renderMarkdown : String -> Result String (List (Element Msg))
renderMarkdown markdown =
    markdown
        |> Markdown.Parser.parse
        |> Result.mapError (\e -> e |> List.map Markdown.Parser.deadEndToString |> String.join "\n")
        |> Result.andThen (Markdown.Renderer.render renderer)


renderer : Markdown.Renderer.Renderer (Element Msg)
renderer =
    { heading = heading
    , paragraph = paragraph [ spacing 10 ]
    , thematicBreak = Element.none
    , text = \t -> el [ width fill ] (text t)
    , strong = row [ Font.bold ]
    , emphasis = row [ Font.italic ]
    , codeSpan = text
    , link =
        \{ title, destination } body ->
            Element.newTabLink
                [ Element.htmlAttribute (Html.Attributes.style "display" "inline-flex") ]
                { url = destination
                , label =
                    Element.paragraph
                        [ Font.color (Element.rgb255 0 0 255)
                        ]
                        body
                }
    , hardLineBreak = Html.br [] [] |> Element.html
    , image = \image -> Element.image [ width fill ] { src = image.src, description = image.alt }
    , blockQuote =
        \children ->
            Element.column
                [ Border.widthEach { top = 0, right = 0, bottom = 0, left = 10 }
                , Element.padding 10
                , Border.color (Element.rgb255 145 145 145)
                , Background.color (Element.rgb255 245 245 245)
                ]
                children
    , unorderedList = unorderedList
    , orderedList = orderedList
    , codeBlock = \s -> Element.none
    , html = Markdown.Html.oneOf []
    , table = column []
    , tableHeader = column []
    , tableBody = column []
    , tableRow = row []
    , tableHeaderCell = \maybeAlignment children -> paragraph [] children
    , tableCell = paragraph []
    }


heading : { level : Block.HeadingLevel, rawText : String, children : List (Element Msg) } -> Element Msg
heading { level, rawText, children } =
    paragraph
        [ Font.size
            (case level of
                Block.H1 ->
                    28

                Block.H2 ->
                    24

                _ ->
                    12
            )
        , Font.regular
        , Region.heading (Block.headingLevelToInt level)
        , paddingEach { edges | bottom = 15, top = 15 }
        ]
        children


unorderedList : List (ListItem (Element Msg)) -> Element Msg
unorderedList items =
    column [ spacing 15, width fill ]
        (items
            |> List.map
                (\(ListItem task children) ->
                    row [ width fill ]
                        [ row [ alignTop, width fill, spacing 5 ]
                            ((case task of
                                IncompleteTask ->
                                    Input.defaultCheckbox False

                                CompletedTask ->
                                    Input.defaultCheckbox True

                                NoTask ->
                                    text "•"
                             )
                                :: text " "
                                :: children
                            )
                        ]
                )
        )


orderedList : Int -> List (List (Element Msg)) -> Element Msg
orderedList startingIndex items =
    column [ spacing 15, width fill ]
        (items
            |> List.indexedMap
                (\index itemBlocks ->
                    row [ spacing 5, width fill ]
                        [ row [ alignTop, width fill, spacing 5 ]
                            (text (String.fromInt (index + startingIndex) ++ " ") :: itemBlocks)
                        ]
                )
        )


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
