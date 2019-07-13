module Page.Recipe.Editor exposing (Model)

import Html exposing (..)
import Http
import Recipe exposing (Full, Recipe)
import Session exposing (Session)



-- MODEL


type alias Model =
    { session : Session
    , status : Status
    }


type Status
    = -- New Article
      EditingNew (List Problem) Form
    | Creating Form


type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type alias Form =
    { title : String
    , description : String
    , instructions : String
    , quantity : Int
    }


initNew : Session -> ( Model, Cmd msg )
initNew session =
    ( { session = session
      , status =
            EditingNew []
                { title = ""
                , description = ""
                , instructions = ""
                , quantity = ""
                }
      }
    , Cmd.none
    )



-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    { title = "New Article"
    , content = text "the form"
    }



-- UPDATE


type Msg
    = ClickedSave
    | EnteredTitle String
    | CompletedCreate (Result Http.Error (Recipe Full))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedSave ->
            model.status
                |> save
                |> Tuple.mapFirst (\status -> { model | status = status })

        EnteredTitle title ->
            updateForm (\form -> { form | title = title }) model


save : Status -> ( Status, Cmd Msg )
save status =
    case status of
        EditingNew _ form ->
            ( Creating form, create form |> Http.send CompletedCreate )


updateForm : (Form -> Form) -> Model -> ( Model, Cmd Msg )
updateForm transform model =
    let
        newModel =
            case model.status of
                EditingNew errors form ->
                    { model | status = EditingNew errors (transform form) }

                Creating form ->
                    { model | status = Creating (transform form) }
    in
    ( newModel, Cmd.none )


type TrimmedForm
    = Trimmed Form


type ValidatedField
    = Title
    | Body
