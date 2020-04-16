module Page.Recipe.Editor exposing (Model, Msg, initEdit, initNew, toSession, update, view)

import Browser.Navigation as Nav
import Element exposing (Element, column, row, text)
import Http exposing (Expect)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Loading
import Page.Recipe.Form as Form
import Recipe exposing (Full, Recipe, ServerError, fullDecoder)
import Recipe.Slug as Slug exposing (Slug)
import Route
import Session exposing (Session(..))
import Url exposing (Url)
import Url.Builder



-- MODEL


type alias Model =
    { session : Session
    , status : Status
    }


type Status
    = -- New Recipe
      EditingNew (Maybe ServerError) Form.Model
    | Creating Form.Model
      -- Edit Recipe
    | Loading Slug
    | LoadingFailed Slug
    | Editing Slug (Maybe ServerError) Form.Model
    | Saving Slug Form.Model


initNew : Session -> ( Model, Cmd Msg )
initNew session =
    let
        toModel subModel =
            { session = session
            , status = EditingNew Nothing subModel
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
    let
        newSession =
            Session.Session (Session.navKey session)
    in
    case Session.recipe session slug of
        Just recipe ->
            ( { session = newSession
              , status = Editing slug Nothing <| Form.fromRecipe recipe
              }
            , Cmd.none
            )

        Nothing ->
            ( { session = newSession
              , status = Loading slug
              }
            , Recipe.fetch slug (CompletedRecipeLoad slug)
            )



-- VIEW


view : Model -> { title : String, content : Element Msg }
view model =
    let
        skeleton prob children =
            column []
                (List.append
                    [ Element.map FormMsg children ]
                    [ viewServerError prob ]
                )
    in
    { title = "Skapa nytt recept"
    , content =
        case model.status of
            -- Creating a new recipe
            EditingNew serverError form ->
                skeleton serverError <| Form.view form

            Creating form ->
                skeleton Nothing <| Form.view form

            -- Editing an existing recipe
            Loading slug ->
                skeleton Nothing (Element.html Loading.animation)

            LoadingFailed slug ->
                let
                    title =
                        Maybe.withDefault "" (Url.percentDecode (Slug.toString slug))
                in
                skeleton Nothing <| Loading.error title "Kunde ej ladda in receptet"

            Editing slug serverError form ->
                skeleton serverError <| Form.view form

            Saving slug form ->
                skeleton Nothing <| Form.view form
    }


viewServerError : Maybe ServerError -> Element Msg
viewServerError maybeError =
    let
        maybeErrorStr =
            Maybe.map Recipe.serverErrorToString maybeError
    in
    case maybeErrorStr of
        Just errorStr ->
            row []
                [ text "Något gick fel när servern försökte spara receptet"
                , text errorStr
                ]

        Nothing ->
            row [] [ Element.none ]


type Msg
    = FormMsg Form.Msg
      -- Msg:s from the server
    | CompletedCreate (Result Recipe.ServerError (Recipe Full))
    | CompletedRecipeLoad Slug (Result Recipe.ServerError (Recipe Full))
    | CompletedEdit (Result Recipe.ServerError (Recipe Full))


formToModel : Model -> Form.Model -> Model
formToModel { status, session } form =
    let
        newStatus =
            case status of
                EditingNew serverError _ ->
                    EditingNew serverError form

                Creating _ ->
                    Creating form

                Editing slug serverError _ ->
                    Editing slug serverError form

                s ->
                    s
    in
    { session = session
    , status = newStatus
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ status, session } as model) =
    case msg of
        FormMsg (Form.SubmitValidForm jsonForm) ->
            jsonForm
                |> save status
                |> Tuple.mapFirst (\newStatus -> { model | status = newStatus })

        FormMsg subMsg ->
            case status of
                EditingNew _ form ->
                    Form.update subMsg form
                        |> updateWith (formToModel model) FormMsg

                Editing slug _ form ->
                    Form.update subMsg form
                        |> updateWith (formToModel model) FormMsg

                Creating form ->
                    Form.update subMsg form
                        |> updateWith (formToModel model) FormMsg

                _ ->
                    -- Disallow editing the form in all other situations
                    ( model, Cmd.none )

        -- Server events
        CompletedRecipeLoad _ (Ok recipe) ->
            let
                newStatus =
                    Editing (Recipe.slug recipe) Nothing (Form.fromRecipe recipe)
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
            ( Creating form, Recipe.create jsonForm CompletedCreate )

        Editing slug _ form ->
            ( Saving slug form, Recipe.edit slug jsonForm CompletedEdit )

        _ ->
            ( status, Cmd.none )


savingError : ServerError -> Status -> Status
savingError error status =
    case status of
        Creating form ->
            EditingNew (Just error) form

        Saving slug form ->
            Editing slug (Just error) form

        _ ->
            status


toSession : Model -> Session
toSession model =
    model.session
