module Page.Test exposing (Model, Msg, init, toSession, view)

import Html exposing (..)
import Session exposing (Session)



-- MODEl


type alias Model =
    { session : Session
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session }, Cmd.none )


view : Model -> { title : String, content : Html Msg }
view model =
    { title = "Test"
    , content = div [] [ text "test" ]
    }


type Msg
    = Massage


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Massage ->
            ( model, Cmd.none )


toSession : Model -> Session
toSession { session } =
    session
