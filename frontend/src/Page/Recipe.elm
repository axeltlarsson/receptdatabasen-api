module Page.Recipe exposing (Model, Msg, init, toSession, update, view)

import Browser exposing (Document)
import Html exposing (..)
import Http
import Json.Decode exposing (Decoder, dict, field, index, map2, string)
import Session exposing (Session)
import Url exposing (Url)
import Url.Builder



--- MODEL


type alias Model =
    { session : Session, recipe : Status Recipe, error : Maybe Http.Error }


type Status a
    = Loading
    | Loaded a
    | Failed


type alias Recipe =
    { title : String
    , instructions : String
    }


init : Session -> Int -> ( Model, Cmd Msg )
init session slug =
    ( { recipe = Loading
      , session = session
      , error = Nothing
      }
    , getRecipe slug
    )



-- VIEW


view : Model -> Document msg
view model =
    case model.recipe of
        Loading ->
            { title = "Loading recipe"
            , body = [ text "Loading..." ]
            }

        Failed ->
            { title = "Failed to load"
            , body =
                [ text "Failed to load"
                , viewError model.error
                ]
            }

        Loaded recipe ->
            { title = "Individual recipe view"
            , body =
                [ div []
                    [ h1 [] [ text recipe.title ]
                    , text "recipe number: "
                    ]
                ]
            }


viewError : Maybe Http.Error -> Html msg
viewError error =
    case error of
        Just (Http.BadUrl str) ->
            text str

        Just Http.NetworkError ->
            text "NetworkError"

        Just (Http.BadStatus status) ->
            text ("BadStatus" ++ String.fromInt status)

        Just (Http.BadBody str) ->
            text ("BadBody" ++ str)

        Just Http.Timeout ->
            text "Timeout"

        Nothing ->
            text ""



-- UPDATE


type Msg
    = LoadedRecipe (Result Http.Error Recipe)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedRecipe (Ok recipe) ->
            ( { model | recipe = Loaded recipe }, Cmd.none )

        LoadedRecipe (Err error) ->
            ( { model | recipe = Failed, error = Just error }, Cmd.none )



-- HTTP


hardCodedUrl : String
hardCodedUrl =
    Url.Builder.crossOrigin "http://localhost:3000" [ "recipes" ] [ Url.Builder.string "id" "eq.4" ]


getRecipe : Int -> Cmd Msg
getRecipe slug =
    Http.get
        { url = hardCodedUrl
        , expect = Http.expectJson LoadedRecipe recipeDecoder
        }


recipeDecoder : Decoder Recipe
recipeDecoder =
    map2 Recipe
        (index 0 (field "title" string))
        (index 0 (field "instructions" string))



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
