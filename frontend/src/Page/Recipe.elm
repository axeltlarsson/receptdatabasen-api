module Page.Recipe exposing (Model, Msg, init, toSession, update, view)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decoder exposing (Decoder, list)
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
    | NotFound


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
    case model.recipe of
        Loading ->
            { title = "Laddar..."
            , content = text ""
            }

        Failed err ->
            { title = "Kunde ej hämta recept"
            , content =
                text <| Recipe.serverErrorToString err
            }

        NotFound ->
            { title = "404"
            , content = text "Kunde ej hitta receptet"
            }

        Loaded recipe ->
            let
                { title } =
                    Recipe.metadata recipe
            in
            { title = Slug.toString title
            , content = viewRecipe recipe
            }


viewRecipe : Recipe Full -> Html Msg
viewRecipe recipe =
    let
        { title, description, id, createdAt } =
            Recipe.metadata recipe

        { portions, ingredients, instructions } =
            Recipe.contents recipe

        portionsStr =
            String.fromInt portions
    in
    div []
        [ h1 [] [ text (Slug.toString title) ]
        , p [] [ text <| String.concat [ "Recept-id: ", String.fromInt id ] ]
        , p [] [ text description ]
        , p [] [ text <| String.concat [ portionsStr, " portioner" ] ]
        , h2 [] [ text "Ingredienser" ]
        , viewIngredientsDict ingredients
        , h2 [] [ text "Instruktioner" ]
        , p [] [ Markdown.toHtmlWith mdOptions [ class "ingredients" ] instructions ]
        , p [] [ text <| String.concat [ "Skapad: ", createdAt ] ]
        , a [ Route.href (Route.EditRecipe (Recipe.slug recipe)) ] [ text "Ändra recept" ]
        , button [ onClick ClickedDelete ] [ text "Radera" ]
        ]


mdOptions : Markdown.Options
mdOptions =
    { githubFlavored = Nothing
    , defaultHighlighting = Nothing
    , sanitize = True
    , smartypants = True
    }


viewIngredientsDict : Dict String (List String) -> Html Msg
viewIngredientsDict ingredients =
    div []
        (Dict.toList ingredients |> List.map viewGroupedIngredients)


viewGroupedIngredients : ( String, List String ) -> Html Msg
viewGroupedIngredients ( groupKey, ingredients ) =
    div []
        [ h3 [] [ text groupKey ]
        , ul []
            (List.map viewIngredient ingredients)
        ]


viewIngredient : String -> Html Msg
viewIngredient ingredient =
    li [] [ text ingredient ]



-- UPDATE


type Msg
    = LoadedRecipe (Result Recipe.ServerError (Recipe Full))
    | ClickedDelete
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

        Deleted (Ok _) ->
            ( model
            , Route.RecipeList
                |> Route.replaceUrl (Session.navKey model.session)
            )

        Deleted (Err error) ->
            ( { model | recipe = Failed (Recipe.ServerError error) }, Cmd.none )



-- HTTP
-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
