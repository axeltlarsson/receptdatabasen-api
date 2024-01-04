module Page.Login exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Api exposing (ServerError, expectJsonWithBody, viewServerError)
import Element exposing (Element, centerX, column, el, fill, padding, paddingEach, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import FeatherIcons
import Form exposing (errorBorder, onEnter, viewValidationError)
import Html.Attributes as HtmlAttributes
import Http
import Json.Decode as Decode exposing (field, int, string)
import Json.Encode as Encode
import Palette
import Passkey
import Route
import Session exposing (Session)
import String.Verify
import Url.Builder
import Verify



-- VIEW


type alias Model =
    { session : Session
    , status : Status
    , problem : Maybe ServerError
    , passkeyAuthentication : PasskeyAuthentication
    }



{-
   Passkey authenticaction with conditional UI.
   1. Immediately, issue a request to server /auth/begin to get registration options
   2. Call the navigator.credentials.get in js-land through port using the "conditional" flag providing the registration options
   3. If user selects passkey, continue with calling /auth/complete with the response from previous step
   4. If successful auth continue to home page
   4. If no selected passkey - abort the conditional call (abortCMA) and do normal username/password auth
-}


type PasskeyAuthentication
    = -- POST /passkeys/authentication/begin without user_name to get options with challenge
      NotSupported
    | AuthBeginLoading
    | AuthBeginFailed Api.ServerError
      -- Get passkey in js-land conditionally with options from AuthBegin, directly then to AuthCompleteLoading
    | FailedGettingCredential String
    | AuthCompleteLoading
    | AuthCompleteFailed Api.ServerError
    | AuthCompleteLoaded Encode.Value


type Status
    = FillingForm LoginForm
    | SubmittingForm LoginForm


type alias LoginForm =
    { userName : String
    , userNameValidationActive : Bool
    , password : String
    , passwordValidationActive : Bool
    , validationStatus : ValidationStatus
    , invalidCredentials : Bool
    }


type ValidationStatus
    = NotActivated
    | Invalid
    | Valid


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , status = FillingForm initialForm
      , problem = Nothing
      , passkeyAuthentication = AuthBeginLoading
      }
    , Passkey.passkeyAuthenticationBegin Nothing LoadedAuthenticationBegin
    )


initialForm : LoginForm
initialForm =
    { userName = ""
    , userNameValidationActive = False
    , password = ""
    , passwordValidationActive = False
    , validationStatus = NotActivated
    , invalidCredentials = False
    }


view : Model -> { title : String, content : Element Msg }
view model =
    { title = "Logga in"
    , content =
        column
            [ Region.mainContent
            , width (fill |> Element.maximum 400)
            , centerX
            , spacing 40
            , padding 10
            ]
            [ row [ Font.heavy, Font.size Palette.xxLarge ] [ text "Logga in" ]
            , case model.status of
                FillingForm form ->
                    viewForm form

                SubmittingForm form ->
                    viewForm form
            , model.problem
                |> Maybe.map (viewServerError "Kunde ej logga in")
                |> Maybe.withDefault Element.none
            , viewPasskeyAuthErrors model.passkeyAuthentication
            ]
    }


viewForm : LoginForm -> Element Msg
viewForm form =
    column [ width fill, Font.extraLight, spacing 20 ]
        [ viewUserNameInput form.invalidCredentials form.userNameValidationActive form.userName
        , viewPasswordInput form.invalidCredentials form.passwordValidationActive form.password
        , viewSubmitButton
        ]


viewUserNameInput : Bool -> Bool -> String -> Element Msg
viewUserNameInput invalidCredentials active name =
    let
        theValidator =
            if invalidCredentials then
                Verify.fail "Fel användarnamn och/eller lösenord"

            else
                userNameValidator

        userIcon =
            el [ paddingEach { left = 0, right = 10, top = 0, bottom = 0 } ]
                (FeatherIcons.user |> FeatherIcons.toHtml [] |> Element.html)
    in
    column [ spacing 10, width fill ]
        [ row [ width fill ]
            [ userIcon
            , Input.username
                ([ Events.onLoseFocus BlurredUserName
                 , Border.rounded 2
                 , Element.htmlAttribute (HtmlAttributes.attribute "autocomplete" "username webauthn")
                 , Element.htmlAttribute (HtmlAttributes.attribute "name" "username")
                 , Element.htmlAttribute (HtmlAttributes.attribute "id" "username")
                 ]
                    ++ errorBorder active name theValidator
                )
                { onChange = UserNameChanged
                , text = name
                , placeholder = Just (Input.placeholder [] (el [] (text "Användarnamn")))
                , label = Input.labelHidden "Användarnamn"
                }
            ]
        , viewValidationError active name theValidator
        ]


viewPasswordInput : Bool -> Bool -> String -> Element Msg
viewPasswordInput invalidCredentials active password =
    let
        theValidator =
            if invalidCredentials then
                Verify.fail "Fel användarnamn och/eller lösenord"

            else
                userNameValidator

        lockIcon =
            el [ paddingEach { left = 0, right = 10, top = 0, bottom = 0 } ]
                (FeatherIcons.lock |> FeatherIcons.toHtml [] |> Element.html)
    in
    column [ spacing 10, width fill ]
        [ row [ width fill ]
            [ lockIcon
            , Input.currentPassword
                ([ Events.onLoseFocus BlurredPassword
                 , Element.htmlAttribute (onEnter SubmitForm)
                 , Border.rounded 2
                 , Element.htmlAttribute (HtmlAttributes.attribute "name" "password")
                 , Element.htmlAttribute (HtmlAttributes.attribute "id" "password")
                 , Element.htmlAttribute (HtmlAttributes.attribute "autocomplete" "current-password")
                 ]
                    ++ errorBorder active password theValidator
                )
                { onChange = PasswordChanged
                , text = password
                , placeholder = Just (Input.placeholder [] (el [] (text "Lösenord")))
                , label = Input.labelHidden "Lösenord"
                , show = False
                }
            ]
        , viewValidationError active password theValidator
        ]


viewSubmitButton : Element Msg
viewSubmitButton =
    Input.button
        [ width fill, Background.color Palette.green, Border.rounded 2, padding 10, Font.color Palette.white ]
        { onPress = Just SubmitForm
        , label = el [ centerX ] (text "Logga in")
        }


viewPasskeyAuthErrors : PasskeyAuthentication -> Element Msg
viewPasskeyAuthErrors passkeyAuth =
    case passkeyAuth of
        NotSupported ->
            Element.none

        AuthBeginFailed err ->
            viewServerError "Passkey-autentiseringsfel" err

        FailedGettingCredential err ->
            viewServerError "Passkey kunde ej hämtas" <| Api.errorFromString err

        AuthCompleteFailed err ->
            let
                alertIcon =
                    el [ paddingEach { left = 0, right = 10, top = 0, bottom = 0 }, Font.color Palette.red ]
                        (FeatherIcons.alertTriangle |> FeatherIcons.toHtml [] |> Element.html)
            in
            case err of
                Api.Unauthorized ->
                    column [ spacing 10, Font.family [ Font.typeface "Courier New", Font.monospace ] ]
                        [ row [ Font.heavy ]
                            [ alertIcon
                            , el [ Font.color Palette.red ] (text "Kunde ej loggga!")
                            ]
                        , text "Har du valt rätt passkey?"
                        ]

                _ ->
                    viewServerError "Passkey-autentiseringsfel" err

        AuthBeginLoading ->
            Element.none

        AuthCompleteLoading ->
            Element.none

        AuthCompleteLoaded _ ->
            Element.none


type Msg
    = UserNameChanged String
    | BlurredUserName
    | PasswordChanged String
    | BlurredPassword
    | SubmitForm
    | CompletedLogin (Result Api.ServerError Encode.Value)
    | LoadedAuthenticationBegin (Result Api.ServerError Encode.Value)
    | LoadedAuthenticationComplete (Result Api.ServerError Encode.Value)
    | PortMsg Decode.Value


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ session, status } as model) =
    case status of
        FillingForm form ->
            case msg of
                UserNameChanged userName ->
                    ( { model | status = FillingForm { form | userName = userName, invalidCredentials = False } }, Cmd.none )

                BlurredUserName ->
                    -- We don't activate username validation here because it gives a poor UX for selecting passkeys
                    ( model, Cmd.none )

                PasswordChanged password ->
                    ( { model | status = FillingForm { form | password = password, invalidCredentials = False } }, Cmd.none )

                BlurredPassword ->
                    ( { model | status = FillingForm { form | passwordValidationActive = True, userNameValidationActive = True } }, Cmd.none )

                SubmitForm ->
                    let
                        activatedForm f valid =
                            { f
                                | userNameValidationActive = True
                                , passwordValidationActive = True
                                , validationStatus = valid
                                , invalidCredentials = False
                            }
                    in
                    case validator form of
                        Ok verifiedForm ->
                            ( { model | status = SubmittingForm (activatedForm form Valid) }
                            , submitForm verifiedForm
                            )

                        Err _ ->
                            ( { model | status = FillingForm (activatedForm form Invalid) }
                            , Cmd.none
                            )

                CompletedLogin (Ok _) ->
                    ( model, Route.replaceUrl (Session.navKey session) (Route.RecipeList Nothing) )

                CompletedLogin (Err _) ->
                    ( model, Cmd.none )

                PortMsg m ->
                    case Decode.decodeValue Passkey.portMsgDecoder m of
                        Ok (Passkey.PasskeyRetrieved passkey) ->
                            ( { model | passkeyAuthentication = AuthCompleteLoading }, Passkey.passkeyAuthenticationComplete passkey LoadedAuthenticationComplete )

                        Ok (Passkey.PasskeyRetrievalFailed err) ->
                            ( { model | passkeyAuthentication = FailedGettingCredential err }, Cmd.none )

                        Ok (Passkey.PasskeySupported False) ->
                            ( { model | passkeyAuthentication = NotSupported }, Cmd.none )

                        Ok _ ->
                            ( { model | passkeyAuthentication = FailedGettingCredential "unexpected message" }, Cmd.none )

                        Err err ->
                            ( { model | passkeyAuthentication = FailedGettingCredential (Decode.errorToString err) }, Cmd.none )

                LoadedAuthenticationBegin (Ok options) ->
                    ( model, Passkey.sendGetPasskeyConditionalMsg options )

                LoadedAuthenticationBegin (Err err) ->
                    ( { model | passkeyAuthentication = AuthBeginFailed err }, Passkey.passkeyAuthenticationBegin Nothing LoadedAuthenticationBegin )

                LoadedAuthenticationComplete (Ok response) ->
                    update (CompletedLogin (Ok response)) { model | passkeyAuthentication = AuthCompleteLoaded response }

                LoadedAuthenticationComplete (Err err) ->
                    ( { model
                        | passkeyAuthentication = AuthCompleteFailed err
                      }
                    , Passkey.passkeyAuthenticationBegin Nothing LoadedAuthenticationBegin
                    )

        SubmittingForm form ->
            case msg of
                CompletedLogin (Ok _) ->
                    ( { model
                        | status = FillingForm { form | invalidCredentials = False }
                        , problem = Nothing
                      }
                    , Cmd.batch
                        [ Passkey.sendAbortCMAMsg
                        , Route.replaceUrl (Session.navKey session) (Route.RecipeList Nothing)
                        ]
                    )

                CompletedLogin (Err err) ->
                    case err of
                        Api.Unauthorized ->
                            ( { model
                                | status = FillingForm { form | invalidCredentials = True }
                              }
                            , Cmd.none
                            )

                        _ ->
                            ( { model | status = FillingForm form, problem = Just err }, Cmd.none )

                _ ->
                    ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Passkey.subscribe PortMsg



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



{--
  - HTTP
  --}


submitForm : VerifiedForm -> Cmd Msg
submitForm form =
    let
        jsonForm =
            Encode.object
                [ ( "user_name", Encode.string form.userName )
                , ( "password", Encode.string form.password )
                ]
    in
    Http.request
        { url = Url.Builder.crossOrigin "/rest/login" [] []
        , method = "POST"
        , timeout = Nothing
        , tracker = Nothing
        , headers = []
        , body = Http.jsonBody jsonForm
        , expect = expectJsonWithBody CompletedLogin (Decode.value)
        }
