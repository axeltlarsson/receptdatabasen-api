module Page.Login exposing (Model, Msg, init, toSession, update, view)

import Element exposing (Element, centerX, column, el, fill, padding, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Http
import Json.Decode as Decode exposing (field, map2, string)
import Json.Encode as Encode
import Palette
import Recipe exposing (ServerError, expectJsonWithBody)
import Session exposing (Session)
import Url.Builder
import Verify



-- VIEW


type alias Model =
    { session : Session, status : Status }


type Status
    = FillingForm LoginForm
    | SubmittingForm LoginForm


type alias LoginForm =
    { userName : String
    , userNameValidationActive : Bool
    , password : String
    , passwordValidationActive : Bool
    , validationStatus : ValidationStatus
    }


type ValidationStatus
    = NotActivated
    | Invalid
    | Valid


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session, status = FillingForm initialForm }, Cmd.none )


initialForm : LoginForm
initialForm =
    { userName = ""
    , userNameValidationActive = False
    , password = ""
    , passwordValidationActive = False
    , validationStatus = NotActivated
    }


view : Model -> { title : String, content : Element Msg }
view model =
    { title = "Logga in"
    , content =
        column [ Region.mainContent, width fill ]
            [ case model.status of
                FillingForm form ->
                    viewForm form

                SubmittingForm form ->
                    viewForm form
            ]
    }


viewForm : LoginForm -> Element Msg
viewForm form =
    column [ width (fill |> Element.maximum 700), centerX, spacing 20, padding 10, Font.extraLight ]
        [ viewUserNameInput form.userNameValidationActive form.userName
        , viewPasswordInput form.passwordValidationActive form.password
        , viewSubmitButton
        ]


viewUserNameInput : Bool -> String -> Element Msg
viewUserNameInput active name =
    column [ spacing 10, width fill ]
        [ Input.username []
            { onChange = UserNameChanged
            , text = name
            , placeholder = Just (Input.placeholder [] (el [] (text "Användarnamn")))
            , label = Input.labelHidden "Användarnamn"
            }
        ]


viewPasswordInput : Bool -> String -> Element Msg
viewPasswordInput active password =
    column [ spacing 10, width fill ]
        [ Input.currentPassword []
            { onChange = PasswordChanged
            , text = password
            , placeholder = Just (Input.placeholder [] (el [] (text "Lösenord")))
            , label = Input.labelHidden "Lösenord"
            , show = False
            }
        ]


viewSubmitButton : Element Msg
viewSubmitButton =
    Input.button
        [ Background.color Palette.green, Border.rounded 2, padding 10, Font.color Palette.white ]
        { onPress = Just SubmitForm
        , label = text "Logga in"
        }


type Msg
    = UserNameChanged String
    | PasswordChanged String
    | SubmitForm
    | CompletedLogin (Result Recipe.ServerError Me)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ session, status } as model) =
    case status of
        FillingForm form ->
            case msg of
                UserNameChanged userName ->
                    ( { model | status = FillingForm { form | userName = userName } }, Cmd.none )

                PasswordChanged password ->
                    ( { model | status = FillingForm { form | password = password } }, Cmd.none )

                SubmitForm ->
                    case validator form of
                        Ok verifiedForm ->
                            ( { model | status = SubmittingForm form }, submitForm verifiedForm )

                        Err err ->
                            ( model, Cmd.none )

                CompletedLogin (Ok me) ->
                    ( model, Cmd.none )

                CompletedLogin (Err err) ->
                    ( model, Cmd.none )

        SubmittingForm form ->
            case msg of
                CompletedLogin (Ok me) ->
                    Debug.log (Debug.toString me)
                        ( { model | status = FillingForm form }, Cmd.none )

                CompletedLogin (Err err) ->
                    Debug.log (Debug.toString err)
                        ( { model | status = FillingForm form }, Cmd.none )

                _ ->
                    ( model, Cmd.none )


toJson : VerifiedForm -> Encode.Value
toJson form =
    Encode.object
        [ ( "email", Encode.string form.userName )
        , ( "password", Encode.string form.password )
        ]


submitForm : VerifiedForm -> Cmd Msg
submitForm form =
    Http.request
        { url = Url.Builder.crossOrigin "/rest/login" [] []
        , method = "POST"
        , timeout = Nothing
        , tracker = Nothing
        , headers = []
        , body = Http.jsonBody (toJson form)
        , expect = expectJsonWithBody CompletedLogin meDecoder
        }


meDecoder : Decode.Decoder Me
meDecoder =
    Decode.map2 Me
        (field "me" (field "name" string))
        (field "me" (field "role" string))


type alias Me =
    { name : String, role : String }



-- {
-- "me": {
-- "email": "alice@email.com",
-- "id": 1,
-- "name": "alice",
-- "role": "customer"
-- }
-- }
{--
  - Validation
  --}


type alias VerifiedForm =
    { userName : String, password : String }


validator : Verify.Validator String LoginForm VerifiedForm
validator =
    Verify.validate VerifiedForm
        |> Verify.keep .userName
        |> Verify.keep .password


toSession : Model -> Session
toSession model =
    model.session
