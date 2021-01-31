port module Page.Recipe.Editor exposing (Model, Msg, initEdit, initNew, subscriptions, toSession, update, view)

import Api exposing (ServerError)
import Browser.Dom as Dom
import Element exposing (Element, centerX, column, el, fill, text, width)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Loading
import Page.Recipe.Form as Form
import Recipe exposing (Full, Recipe)
import Recipe.Slug as Slug exposing (Slug)
import Route
import Session exposing (Session)
import Task
import Url


port editorPortReceiver : (Decode.Value -> msg) -> Sub msg



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

        ( model, msg ) =
            Form.init |> updateWith toModel FormMsg
    in
    ( model, Cmd.batch [ msg, resetViewport ] )


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
    case Session.recipe session slug of
        Just recipe ->
            ( { session = session
              , status = Editing slug Nothing <| Form.fromRecipe recipe
              }
            , resetViewport
            )

        Nothing ->
            ( { session = session
              , status = Loading slug
              }
            , Cmd.batch
                [ Recipe.fetch slug (CompletedRecipeLoad slug)
                , resetViewport
                ]
            )


resetViewport : Cmd Msg
resetViewport =
    Task.perform (\_ -> SetViewport) (Dom.setViewport 0 0)



-- VIEW


view : Model -> { title : String, content : Element Msg }
view model =
    let
        skeleton prob children =
            column [ width fill ]
                (List.append
                    [ Element.map FormMsg children ]
                    [ el [ centerX ]
                        (prob
                            |> (Maybe.map (Api.viewServerError "Något gick fel när receptet skulle sparas!")
                                    >> Maybe.withDefault Element.none
                               )
                        )
                    ]
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
                skeleton Nothing <| text (title ++ "Kunde ej ladda in receptet")

            Editing slug serverError form ->
                skeleton serverError <| Form.view form

            Saving slug form ->
                skeleton Nothing <| Form.view form
    }


type Msg
    = FormMsg Form.Msg
    | CompletedCreate (Result Api.ServerError (Recipe Full))
    | CompletedRecipeLoad Slug (Result Api.ServerError (Recipe Full))
    | CompletedEdit (Result Api.ServerError (Recipe Full))
    | PortMsg Decode.Value
    | GotImageUploadProgress Int Http.Progress
    | SetViewport


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
update msg ({ status } as model) =
    case msg of
        FormMsg (Form.SubmitValidForm jsonForm) ->
            jsonForm
                |> save status
                |> Tuple.mapFirst (\newStatus -> { model | status = newStatus })

        FormMsg subMsg ->
            let
                updateForm form =
                    Form.update subMsg form
                        |> updateWith (formToModel model) FormMsg
            in
            case status of
                EditingNew _ form ->
                    updateForm form

                Editing _ _ form ->
                    updateForm form

                Creating form ->
                    updateForm form

                -- Disallow editing the form in all other situations:
                Loading _ ->
                    ( model, Cmd.none )

                LoadingFailed _ ->
                    ( model, Cmd.none )

                Saving _ _ ->
                    ( model, Cmd.none )

        PortMsg value ->
            let
                updateFormWithPortMsg form =
                    Form.update (Form.portMsg value) form
                        |> updateWith (formToModel model) FormMsg
            in
            case status of
                EditingNew _ form ->
                    updateFormWithPortMsg form

                Editing _ _ form ->
                    updateFormWithPortMsg form

                Creating form ->
                    updateFormWithPortMsg form

                Loading _ ->
                    ( model, Cmd.none )

                LoadingFailed _ ->
                    ( model, Cmd.none )

                Saving _ _ ->
                    ( model, Cmd.none )

        GotImageUploadProgress idx progress ->
            let
                updateFormWithUploadProgress form =
                    Form.update (Form.uploadProgressMsg idx progress) form
                        |> updateWith (formToModel model) FormMsg
            in
            case status of
                EditingNew _ form ->
                    updateFormWithUploadProgress form

                Editing _ _ form ->
                    updateFormWithUploadProgress form

                Creating form ->
                    updateFormWithUploadProgress form

                Loading _ ->
                    ( model, Cmd.none )

                LoadingFailed _ ->
                    ( model, Cmd.none )

                Saving _ _ ->
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
            ( { model | session = Session.addRecipe recipe model.session }
            , Route.Recipe (Recipe.slug recipe)
                |> Route.replaceUrl (Session.navKey model.session)
            )

        CompletedCreate (Err Api.Unauthorized) ->
            ( model, Route.pushUrl (Session.navKey (toSession model)) Route.Login )

        CompletedCreate (Err error) ->
            ( { model | status = savingError error model.status }
            , Cmd.none
            )

        CompletedEdit (Ok recipe) ->
            ( { model | session = Session.addRecipe recipe model.session }
            , Route.Recipe (Recipe.slug recipe)
                |> Route.replaceUrl (Session.navKey model.session)
            )

        CompletedEdit (Err error) ->
            ( { model | status = savingError error model.status }
            , Cmd.none
            )

        SetViewport ->
            ( model, Cmd.none )


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


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ editorPortReceiver PortMsg
        , Http.track "image0" (GotImageUploadProgress 0)
        , Http.track "image1" (GotImageUploadProgress 1)
        , Http.track "image2" (GotImageUploadProgress 2)
        , Http.track "image3" (GotImageUploadProgress 3)
        , Http.track "image4" (GotImageUploadProgress 4)
        ]
