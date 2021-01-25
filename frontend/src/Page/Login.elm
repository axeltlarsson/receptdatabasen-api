module Page.Login exposing (Model, Msg, init, toSession, update, view)

import Browser.Navigation as Nav
import Element exposing (Element, centerX, column, el, fill, padding, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Http
import Json.Decode as Decode exposing (field, map2, string)
import Json.Encode as Encode
import Page.Recipe.Form exposing (errorBorder, viewValidationError)
import Palette
import Recipe exposing (ServerError, expectJsonWithBody)
import Session exposing (Session)
import String.Verify
import Url.Builder
import Verify



-- VIEW


type alias Model =
    { session : Session, status : Status, problem : Maybe String }


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
    ( { session = session, status = FillingForm initialForm, problem = Nothing }, Cmd.none )


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
            , viewProblem model.problem
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
        [ Input.username ([ Events.onLoseFocus BlurredUserName ] ++ errorBorder active name userNameValidator)
            { onChange = UserNameChanged
            , text = name
            , placeholder = Just (Input.placeholder [] (el [] (text "Användarnamn")))
            , label = Input.labelHidden "Användarnamn"
            }
        , viewValidationError active name userNameValidator
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


viewProblem : Maybe String -> Element Msg
viewProblem problem =
    problem |> Maybe.map (\prob -> text prob) |> Maybe.withDefault Element.none


type Msg
    = UserNameChanged String
    | BlurredUserName
    | PasswordChanged String
    | BlurredPassword
    | SubmitForm
    | CompletedLogin (Result Recipe.ServerError Me)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ session, status } as model) =
    case status of
        FillingForm form ->
            case msg of
                UserNameChanged userName ->
                    ( { model | status = FillingForm { form | userName = userName } }, Cmd.none )

                BlurredUserName ->
                    ( { model | status = FillingForm { form | userNameValidationActive = True } }, Cmd.none )

                PasswordChanged password ->
                    ( { model | status = FillingForm { form | password = password } }, Cmd.none )

                BlurredPassword ->
                    ( { model | status = FillingForm { form | passwordValidationActive = True } }, Cmd.none )

                SubmitForm ->
                    let
                        activatedForm f valid =
                            { f
                                | userNameValidationActive = True
                                , passwordValidationActive = True
                                , validationStatus = valid
                            }
                    in
                    case validator form of
                        Ok verifiedForm ->
                            ( { model | status = SubmittingForm (activatedForm form Valid) }
                            , submitForm verifiedForm
                            )

                        Err err ->
                            ( { model | status = FillingForm (activatedForm form Invalid) }
                            , Cmd.none
                            )

                CompletedLogin (Ok me) ->
                    ( model, Cmd.none )

                CompletedLogin (Err err) ->
                    ( model, Cmd.none )

        SubmittingForm form ->
            case msg of
                CompletedLogin (Ok me) ->
                    ( { model | status = FillingForm form }, Nav.back (Session.navKey session) 1 )

                CompletedLogin (Err err) ->
                    case err of
                        Recipe.ServerErrorWithBody (Http.BadStatus 400) body ->
                            ( { model | problem = Just body, status = FillingForm form }, Cmd.none )

                        _ ->
                            ( { model | status = FillingForm form }, Cmd.none )

                _ ->
                    ( model, Cmd.none )


toJson : VerifiedForm -> Encode.Value
toJson form =
    Encode.object
        [ ( "user_name", Encode.string form.userName )
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
        (field "me" (field "user_name" string))
        (field "me" (field "role" string))


type alias Me =
    { userName : String, role : String }



{--
  - Validation
  --}


type alias VerifiedForm =
    { userName : String, password : String }


validator : Verify.Validator String LoginForm VerifiedForm
validator =
    Verify.validate VerifiedForm
        |> Verify.verify .userName userNameValidator
        |> Verify.verify .password passwordValidator


trim : Verify.Validator error String String
trim input =
    Ok (String.trim input)


userNameValidator : Verify.Validator String String String
userNameValidator =
    trim
        |> Verify.compose (String.Verify.notBlank "Vänligen fyll i ditt användarnamn.")
        |> Verify.compose (String.Verify.minLength 2 "Ett användarnamn är minst 2 tecken långt...")


passwordValidator : Verify.Validator String String String
passwordValidator =
    trim
        |> Verify.compose (String.Verify.notBlank "Vänligen fyll i ditt lösenord.")


toSession : Model -> Session
toSession model =
    model.session
