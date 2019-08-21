module Page.Recipe.Editor exposing (Model, Msg, initEdit, initNew, toSession, update, view)

import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (class, for, id, min, placeholder, style, type_, value)
import Html.Events exposing (keyCode, onInput, onSubmit, preventDefaultOn)
import Http exposing (Expect)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Page.Form as Form
import Recipe exposing (Full, Recipe, fetch, fullDecoder)
import Recipe.Slug as Slug exposing (Slug)
import Route
import Session exposing (Session(..))
import Task
import Url.Builder



-- MODEL


type alias Model =
    { session : Session
    , status : Status
    }


type Status
    = -- New Recipe
      EditingNew (List Problem) Form.Model
    | Creating Form.Model
      -- Edit Recipe
    | Loading Slug
    | LoadingFailed Slug
    | Editing Slug (List Problem) Form.Model
    | Saving Slug Form.Model


type Problem
    = ServerProblem String


initNew : Session -> ( Model, Cmd Msg )
initNew session =
    let
        toModel subModel =
            { session = session
            , status = EditingNew [] subModel
            }
    in
    Form.init |> updateWith toModel FormMsg


updateWith :
    (subModel -> Model)
    -> (subMsg -> Msg)
    -> ( subModel, Cmd subMsg )
    -> ( Model, Cmd Msg )
updateWith toModel toMsg ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )


initEdit : Session -> Slug -> ( Model, Cmd Msg )
initEdit session slug =
    ( { session = session
      , status = Loading slug
      }
    , Recipe.fetch slug (CompletedRecipeLoad slug)
    )



-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    let
        skeleton children =
            div [ class "editor" ] [ Html.map FormMsg children ]
    in
    { title = "Skapa nytt recept"
    , content =
        case model.status of
            -- Creating a new recipe
            EditingNew probs form ->
                skeleton <| Form.view form

            Creating form ->
                skeleton <| Form.view form

            -- Editing an existing recipe
            Loading slug ->
                skeleton <| text "Laddar..."

            LoadingFailed slug ->
                skeleton <| text ("Kunde ej ladda in recept: " ++ Slug.toString slug)

            Editing slug probs form ->
                skeleton <| Form.view form

            Saving slug form ->
                skeleton <| Form.view form
    }


type Msg
    = FormMsg Form.Msg
      -- Msg:s from the server
    | CompletedCreate (Result ServerError (Recipe Full))
    | CompletedRecipeLoad Slug (Result Http.Error (Recipe Full))
    | CompletedEdit (Result ServerError (Recipe Full))


formToModel : Model -> Form.Model -> Model
formToModel { status, session } form =
    let
        newStatus =
            case status of
                EditingNew probs _ ->
                    EditingNew probs form

                Creating _ ->
                    Creating form

                Editing slug probs _ ->
                    Editing slug probs form

                s ->
                    s
    in
    { session = session
    , status = newStatus
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ status, session } as model) =
    case msg of
        FormMsg Form.Submit ->
            case Form.toJson model of
                Just jsonForm ->
                    jsonForm
                        |> save status
                        |> Tuple.mapFirst (\newStatus -> { model | status = newStatus })

                Nothing ->
                    ( model, Cmd.none )

        FormMsg subMsg ->
            case status of
                EditingNew _ form ->
                    Debug.log ("editor - " ++ Debug.toString subMsg)
                        Form.update
                        subMsg
                        form
                        |> updateWith (formToModel model) FormMsg

                Creating form ->
                    Debug.log ("editor - " ++ Debug.toString subMsg)
                        Form.update
                        subMsg
                        form
                        |> updateWith (formToModel model) FormMsg

                _ ->
                    Debug.log "editor - disallowed edit!"
                        -- Disallow editing the form in all other situations
                        ( model, Cmd.none )

        -- Server events
        CompletedRecipeLoad _ (Ok recipe) ->
            let
                newStatus =
                    Editing (Recipe.slug recipe)
                        []
                        (Form.fromRecipe recipe)
            in
            ( { model | status = newStatus }, Cmd.none )

        CompletedRecipeLoad slug (Err error) ->
            ( { model | status = LoadingFailed slug }, Cmd.none )

        CompletedCreate (Ok recipe) ->
            ( { model | session = SessionWithRecipe recipe (Session.navKey model.session) }
            , Route.Recipe (Recipe.slug recipe)
                |> Route.replaceUrl (Session.navKey model.session)
            )

        CompletedCreate (Err error) ->
            ( { model | status = savingError error model.status }
            , Cmd.none
            )

        CompletedEdit (Ok recipe) ->
            ( { model | session = SessionWithRecipe recipe (Session.navKey model.session) }
            , Route.Recipe (Recipe.slug recipe)
                |> Route.replaceUrl (Session.navKey model.session)
            )

        CompletedEdit (Err error) ->
            ( { model | status = savingError error model.status }
            , Cmd.none
            )


save : Status -> Encode.Value -> ( Status, Cmd Msg )
save status jsonForm =
    case status of
        EditingNew _ form ->
            ( Creating form, create jsonForm )

        Editing slug _ form ->
            ( Saving slug form, edit slug jsonForm )

        _ ->
            ( status, Cmd.none )


savingError : ServerError -> Status -> Status
savingError error status =
    let
        problems =
            [ ServerProblem ("Error saving " ++ serverErrorToString error) ]
    in
    case status of
        Creating form ->
            EditingNew problems form

        Saving slug form ->
            Editing slug problems form

        _ ->
            status


serverErrorToString : ServerError -> String
serverErrorToString error =
    case error of
        ServerError (Http.BadUrl str) ->
            "BadUrl" ++ str

        ServerError Http.NetworkError ->
            "NetworkError"

        ServerErrorWithBody (Http.BadStatus status) body ->
            "BadStatus " ++ String.fromInt status ++ body

        ServerError (Http.BadBody str) ->
            "BadBody: " ++ str

        ServerError Http.Timeout ->
            "Timeout"

        _ ->
            ""


createUrl : String
createUrl =
    Url.Builder.crossOrigin "http://localhost:3000" [ "recipes" ] []


editUrl : Slug -> String
editUrl slug =
    Url.Builder.crossOrigin "http://localhost:3000"
        [ "recipes" ]
        [ Url.Builder.string "title" (String.concat [ "eq.", Slug.toString slug ]) ]


edit : Slug -> Encode.Value -> Cmd Msg
edit slug jsonForm =
    Http.request
        { url = editUrl slug
        , method = "PATCH"
        , timeout = Nothing
        , tracker = Nothing
        , headers =
            [ Http.header "Prefer" "return=representation"
            , Http.header "Accept" "application/vnd.pgrst.object+json"
            ]
        , body = Http.jsonBody jsonForm
        , expect = expectJsonWithBody CompletedEdit Recipe.fullDecoder
        }


create : Encode.Value -> Cmd Msg
create jsonForm =
    Http.request
        { url = createUrl
        , method = "POST"
        , timeout = Nothing
        , tracker = Nothing
        , headers =
            [ Http.header "Prefer" "return=representation"
            , Http.header "Accept" "application/vnd.pgrst.object+json"
            ]
        , body = Http.jsonBody jsonForm
        , expect = expectJsonWithBody CompletedCreate Recipe.fullDecoder
        }


type ServerError
    = ServerError Http.Error
    | ServerErrorWithBody Http.Error String


expectJsonWithBody : (Result ServerError a -> Msg) -> Decoder a -> Expect Msg
expectJsonWithBody toMsg decoder =
    Http.expectStringResponse toMsg <|
        \response ->
            case response of
                Http.BadUrl_ urll ->
                    Err (ServerError (Http.BadUrl urll))

                Http.Timeout_ ->
                    Err (ServerError Http.Timeout)

                Http.NetworkError_ ->
                    Err (ServerError Http.NetworkError)

                Http.BadStatus_ metadata body ->
                    Err (ServerErrorWithBody (Http.BadStatus metadata.statusCode) body)

                Http.GoodStatus_ metadata body ->
                    case Decode.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err (ServerError (Http.BadBody (Decode.errorToString err)))


toSession : Model -> Session
toSession model =
    model.session
