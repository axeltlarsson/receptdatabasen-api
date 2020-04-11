module Page.Recipe exposing (Model, Msg, init, toSession, update, view)

-- import Html exposing (..)
-- import Html.Attributes exposing (class, src, style)
-- import Html.Events exposing (onClick)

import Dict exposing (Dict)
import Element exposing (Element, alignLeft, alignRight, alignTop, centerX, centerY, column, el, fill, height, padding, paragraph, rgb255, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Html exposing (Html)
import Http
import Json.Decode as Decoder exposing (Decoder, list)
import Loading
import Markdown
import Recipe exposing (Full, Metadata, Recipe, contents, fullDecoder, metadata)
import Recipe.Slug as Slug exposing (Slug)
import Route
import Session exposing (Session(..))
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
    let
        newSession =
            Session.Session (Session.navKey session)
    in
    case Session.recipe session slug of
        Just recipe ->
            ( { recipe = Loaded recipe
              , session = newSession
              }
            , Cmd.none
            )

        Nothing ->
            ( { recipe = Loading
              , session = newSession
              }
            , Recipe.fetch slug LoadedRecipe
            )



-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    let
        ui =
            viewUi model
    in
    { title = ui.title
    , content =
        Element.layout
            [ padding 10
            , Region.mainContent
            ]
            ui.content
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
            , content = Element.html <| Loading.error "Kunde ej ladda in recept" (Recipe.serverErrorToString err)
            }

        Loaded recipe ->
            let
                { title } =
                    Recipe.metadata recipe
            in
            { title = Slug.toString title
            , content = viewRecipe recipe
            }


viewRecipe : Recipe Full -> Element Msg
viewRecipe recipe =
    let
        { title, description, id, createdAt } =
            Recipe.metadata recipe

        { portions, ingredients, instructions } =
            Recipe.contents recipe

        portionsStr =
            String.fromInt portions
    in
    column [ spacing 30 ]
        [ viewTitle <| Slug.toString title
        , viewDescription description
        , row [ spacing 30 ]
            [ viewInstructions instructions
            , viewVerticalLine
            , viewIngredients ingredients
            ]
        , row [ spacing 20 ]
            [ viewEditButton
            , viewDeleteButton
            ]
        ]


viewTitle : String -> Element Msg
viewTitle title =
    el
        [ padding 30
        , Font.size 48
        ]
        (text title)


viewDescription : Maybe String -> Element Msg
viewDescription description =
    el
        [ padding 30
        ]
        (paragraph [] [ text <| Maybe.withDefault "" description ])


viewInstructions : String -> Element Msg
viewInstructions instructions =
    column [ alignTop, alignLeft, width fill ]
        [ el [ padding 10, Font.size 28 ] (text "Gör så här")
        , el [] (paragraph [] [ text instructions ])
        ]


viewVerticalLine : Element Msg
viewVerticalLine =
    let
        white =
            rgb255 0 0 0

        black =
            rgb255 255 255 255
    in
    column
        [ height (fill |> Element.maximum 1000)
        ]
        [ column
            [ Element.height fill
            , Element.width (Element.px 1)

            -- , Background.color (Element.rgb255 70 70 70)
            , Background.gradient { angle = 2, steps = [ black, white, black ] } -- TODO: This is cheesy
            ]
            []
        ]


viewIngredients : Dict String (List String) -> Element Msg
viewIngredients ingredients =
    column [ alignRight, alignTop, width fill ]
        [ el [ padding 10, Font.size 28 ] (text "Ingredienser")
        , column [] (Dict.toList ingredients |> List.map viewGroupedIngredients)
        ]


debug : Element.Attribute Msg
debug =
    Element.explain Debug.todo


viewGroupedIngredients : ( String, List String ) -> Element Msg
viewGroupedIngredients ( groupKey, ingredients ) =
    column [ spacing 20, padding 10 ]
        [ el [ Font.heavy ] (text groupKey)
        , column [ spacing 10 ] (List.map viewIngredient ingredients)
        ]


viewIngredient : String -> Element Msg
viewIngredient ingredient =
    el [] (text ingredient)


pancakeImgUrl : String
pancakeImgUrl =
    "url(https://assets.icanet.se/q_auto,f_auto/imagevaultfiles/id_185874/cf_259/pannkakstarta-med-choklad-och-nutella-724305-stor.jpg)"


viewDeleteButton : Element Msg
viewDeleteButton =
    Input.button
        [ Background.color (rgb255 255 0 0), Border.rounded 3, padding 10, Font.color (rgb255 30 30 30) ]
        { onPress = Just ClickedDelete
        , label = text "Radera"
        }


viewEditButton : Element Msg
viewEditButton =
    Input.button
        [ Background.color (rgb255 255 127 0), Border.rounded 3, padding 10, Font.color (rgb255 30 30 30) ]
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
            ( { model | recipe = Loaded recipe, session = SessionWithRecipe recipe (Session.navKey model.session) }, Cmd.none )

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
            ( { model | recipe = Failed (Recipe.ServerError error) }, Cmd.none )



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
