module Page.Recipe exposing (Model, Msg, init, toSession, update, view)

import Browser exposing (Document)
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (class)
import Http
import Markdown
import Recipe exposing (Full, Metadata, Recipe, contents, fullDecoder, metadata)
import Session exposing (Session)
import Url exposing (Url)
import Url.Builder



--- MODEL


type alias Model =
    { session : Session, recipe : Status (Recipe Full) }


type Status recipe
    = Loading
    | Loaded recipe
    | Failed Http.Error
    | NotFound


type alias Slug =
    Int


init : Session -> Slug -> ( Model, Cmd Msg )
init session slug =
    ( { recipe = Loading
      , session = session
      }
    , getRecipe slug
    )



-- VIEW


view : Model -> Document Msg
view model =
    case model.recipe of
        Loading ->
            { title = "Loading recipe"
            , body = [ text "" ]
            }

        Failed err ->
            { title = "Failed to load"
            , body =
                [ text "Failed to load "
                , viewError err
                ]
            }

        NotFound ->
            { title = "Not found"
            , body = [ text "Not found" ]
            }

        Loaded recipe ->
            let
                { title } =
                    Recipe.metadata recipe
            in
            { title = title
            , body = [ viewRecipe recipe ]
            }


viewRecipe : Recipe Full -> Html Msg
viewRecipe recipe =
    let
        { title, slug, createdAt } =
            Recipe.metadata recipe

        slugStr =
            String.fromInt slug

        { description, quantity, ingredients, instructions } =
            Recipe.contents recipe

        quantityStr =
            String.fromInt quantity
    in
    div []
        [ h1 [] [ text title ]
        , p [] [ text <| String.concat [ "Recipe id: ", slugStr ] ]
        , p [] [ text description ]
        , p [] [ text <| String.concat [ "För ", quantityStr, " personer" ] ]
        , h2 [] [ text "Ingredienser" ]
        , viewIngredientsDict ingredients
        , h2 [] [ text "Instruktioner" ]
        , p [] [ Markdown.toHtmlWith mdOptions [ class "ingredients" ] instructions ]
        , p [] [ text <| String.concat [ "Skapad: ", createdAt ] ]
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


viewError : Http.Error -> Html Msg
viewError error =
    case error of
        Http.BadUrl str ->
            text str

        Http.NetworkError ->
            text "NetworkError"

        Http.BadStatus status ->
            text ("BadStatus " ++ String.fromInt status)

        Http.BadBody str ->
            text ("BadBody " ++ str)

        Http.Timeout ->
            text "Timeout"



-- UPDATE


type Msg
    = LoadedRecipe (Result Http.Error (List (Recipe Full)))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedRecipe (Ok [ recipe ]) ->
            ( { model | recipe = Loaded recipe }, Cmd.none )

        LoadedRecipe (Ok []) ->
            ( { model | recipe = NotFound }, Cmd.none )

        LoadedRecipe (Err error) ->
            ( { model | recipe = Failed error }, Cmd.none )

        LoadedRecipe (Ok _) ->
            Debug.todo "Multiple recipes matched"



-- HTTP


url : Slug -> String
url slug =
    Url.Builder.crossOrigin "http://localhost:3000" [ "recipes" ] [ Url.Builder.string "id" ("eq." ++ String.fromInt slug) ]


getRecipe : Slug -> Cmd Msg
getRecipe slug =
    Http.get
        { url = url slug
        , expect = Http.expectJson LoadedRecipe Recipe.fullDecoder
        }



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
