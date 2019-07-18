module Page.Recipe.Editor exposing (Model, Msg, initNew, toSession, update, view)

import Browser exposing (Document)
import Html exposing (..)
import Html.Attributes exposing (placeholder, value)
import Html.Events exposing (onInput, onSubmit)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Recipe exposing (Full, Recipe, fullDecoder)
import Session exposing (Session)
import Url
import Url.Builder



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
                , quantity = 0
                }
      }
    , Cmd.none
    )



-- VIEW


view : Model -> Document Msg
view model =
    { title = "New Recipe"
    , body =
        [ case model.status of
            EditingNew probs form ->
                viewForm form

            Creating form ->
                viewForm form
        ]
    }


viewForm : Form -> Html Msg
viewForm fields =
    form [ onSubmit ClickedSave ]
        [ input
            [ placeholder "Recipe Title"
            , onInput EnteredTitle
            , value fields.title
            ]
            []
        , button []
            [ text "Save" ]
        ]



-- UPDATE


type Msg
    = ClickedSave
    | EnteredTitle String
    | CompletedCreate (Result Http.Error (List (Recipe Full)))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedSave ->
            model.status
                |> save
                |> Tuple.mapFirst (\status -> { model | status = status })

        EnteredTitle title ->
            updateForm (\form -> { form | title = title }) model

        CompletedCreate (Ok recipes) ->
            updateForm (\form -> { form | title = "saved" }) model

        CompletedCreate (Err error) ->
            updateForm (\form -> { form | title = "error" }) model


save : Status -> ( Status, Cmd Msg )
save status =
    case status of
        EditingNew _ form ->
            ( Creating form, create form )

        _ ->
            ( status, Cmd.none )


url : String
url =
    Url.Builder.crossOrigin "http://localhost:3000" [ "recipes" ] []


create : Form -> Cmd Msg
create form =
    let
        body =
            Encode.object [ ( "recipe", Encode.string form.title ) ] |> Http.jsonBody
    in
    Http.post
        { url = url
        , body = body
        , expect = Http.expectJson CompletedCreate Recipe.fullDecoder
        }


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


toSession : Model -> Session
toSession model =
    model.session
