module Page.Login exposing (Model, Msg, init, toSession, update, view)

import Api exposing (ServerError, expectJsonWithBody, viewServerError)
import Browser.Navigation as Nav
import Element exposing (Element, centerX, column, el, fill, padding, paddingEach, paddingXY, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import FeatherIcons
import Form exposing (errorBorder, onEnter, viewValidationError)
import Http
import Json.Decode as Decode exposing (field, map2, string)
import Json.Encode as Encode
import Palette
import Route
import Session exposing (Session)
import String.Verify
import Url.Builder
import Verify



-- VIEW


type alias Model =
    { session : Session, status : Status, problem : Maybe ServerError }


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
    ( { session = session, status = FillingForm initialForm, problem = Nothing }, Cmd.none )


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


type Msg
    = UserNameChanged String
    | BlurredUserName
    | PasswordChanged String
    | BlurredPassword
    | SubmitForm
    | CompletedLogin (Result Api.ServerError Me)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ session, status } as model) =
    case status of
        FillingForm form ->
            case msg of
                UserNameChanged userName ->
                    ( { model | status = FillingForm { form | userName = userName, invalidCredentials = False } }, Cmd.none )

                BlurredUserName ->
                    ( { model | status = FillingForm { form | userNameValidationActive = True, invalidCredentials = False } }, Cmd.none )

                PasswordChanged password ->
                    ( { model | status = FillingForm { form | password = password, invalidCredentials = False } }, Cmd.none )

                BlurredPassword ->
                    ( { model | status = FillingForm { form | passwordValidationActive = True } }, Cmd.none )

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
                    ( { model
                        | status = FillingForm { form | invalidCredentials = False }
                        , problem = Nothing
                      }
                    , Route.replaceUrl (Session.navKey session) (Route.RecipeList Nothing)
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
        , expect = expectJsonWithBody CompletedLogin meDecoder
        }


meDecoder : Decode.Decoder Me
meDecoder =
    Decode.map2 Me
        (field "me" (field "user_name" string))
        (field "me" (field "role" string))


type alias Me =
    { userName : String, role : String }
