module Page.Recipe exposing (Model, Msg, init, toSession, update, view)

import Browser exposing (Document)
import Html exposing (..)
import Session exposing (Session)



--- MODEL


type alias Model =
    { session : Session, recipe : Status Recipe }


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
      }
    , Cmd.none
    )



-- VIEW


view : Model -> Document msg
view model =
    { title = "Individual recipe view"
    , body =
        [ div []
            [ h1 [] [ text "Individual recipe" ]
            , text "recipe number: "
            ]
        ]
    }



-- UPDATE


type Msg
    = LoadedRecipe (Result String Recipe)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedRecipe (Ok recipe) ->
            ( { model | recipe = Loaded recipe }, Cmd.none )

        LoadedRecipe (Err error) ->
            ( { model | recipe = Failed }, Cmd.none )



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
