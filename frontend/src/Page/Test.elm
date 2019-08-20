module Page.Test exposing (Model, Msg, init, toSession, update, view)

import Html exposing (..)
import Page.Form as Form
import Session exposing (Session)



-- MODEL


type alias Model =
    { session : Session
    , form : Form.Model
    }


formToModel : Session -> Form.Model -> Model
formToModel session form =
    { session = session
    , form = form
    }


init : Session -> ( Model, Cmd Msg )
init session =
    Form.init |> updateWith (formToModel session) FormMsg


updateWith : (subModel -> Model) -> (subMsg -> Msg) -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )



-- VIEW


view : Model -> { title : String, content : Html Msg }
view { form } =
    { title = "Test"
    , content = div [] [ Html.map FormMsg (Form.view form) ]
    }


toSession : Model -> Session
toSession { session } =
    session



-- UPDATE


type Msg
    = FormMsg Form.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg { form, session } =
    case msg of
        FormMsg subMsg ->
            Form.update subMsg form
                |> updateWith (formToModel session) FormMsg
