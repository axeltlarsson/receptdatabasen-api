module Page.Recipe exposing (Model, Msg, init, toSession, update, view)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (class)
import Http
import Json.Decode as Decoder exposing (Decoder, list)
import Markdown
import Recipe exposing (Full, Metadata, Recipe, contents, fullDecoder, metadata)
import Recipe.Slug as Slug exposing (Slug)
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


init : Session -> Slug -> ( Model, Cmd Msg )
init session slug =
    ( { recipe = Loading
      , session = session
      }
    , getRecipe slug
    )



-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    case model.recipe of
        Loading ->
            { title = "Loading recipe"
            , content = text ""
            }

        Failed err ->
            { title = "Failed to load"
            , content =
                viewError err
            }

        NotFound ->
            { title = "Not found"
            , content = text "Not found"
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
        { title, id, createdAt } =
            Recipe.metadata recipe

        { description, quantity, ingredients, instructions } =
            Recipe.contents recipe

        quantityStr =
            String.fromInt quantity
    in
    div []
        [ h1 [] [ text (Slug.toString title) ]
        , p [] [ text <| String.concat [ "Recipe id: ", String.fromInt id ] ]
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
    = LoadedRecipe (Result Http.Error (Recipe Full))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedRecipe (Ok recipe) ->
            ( { model | recipe = Loaded recipe }, Cmd.none )

        LoadedRecipe (Err error) ->
            ( { model | recipe = Failed error }, Cmd.none )



-- HTTP


url : Slug -> String
url slug =
    Url.Builder.crossOrigin "http://localhost:3000" [ "recipes" ] [ Url.Builder.string "title" "eq." ]


getRecipe : Slug -> Cmd Msg
getRecipe slug =
    Http.request
        { url = url slug ++ Slug.toString slug
        , method = "GET"
        , timeout = Nothing
        , tracker = Nothing
        , headers = [ Http.header "Accept" "application/vnd.pgrst.object+json" ]
        , body = Http.emptyBody
        , expect = Http.expectJson LoadedRecipe Recipe.fullDecoder
        }



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
