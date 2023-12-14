module Page.MyProfile exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Api exposing (viewServerError)
import Element
    exposing
        ( Element
        , alignLeft
        , column
        , el
        , fill
        , padding
        , paragraph
        , row
        , spacing
        , spacingXY
        , text
        , width
        )
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import FeatherIcons
import Json.Decode as Decode
import Json.Encode as Encode
import Loading
import Palette
import Passkey
    exposing
        ( Passkey
        , Profile
        , passkeyPortReceiver
        , sendCheckPasskeySupportMsg
        , sendCreatePasskeyMsg
        , sendGetPasskeyMsg
        )
import Route
import Session exposing (Session)


type alias Model =
    { session : Session
    , profile : Status Profile
    , registeredPasskeys : Status (List Passkey)
    , passkeyRegistration : PasskeyRegistration
    , passkeyAuthentication : PasskeyAuthentication
    }



{-
   Passkey registration requires a number of steps

   1. Check for client support -> `CheckingSupport` | `Supported` | `NotSupported`
   2. Call the BE /passkeys/registration/begin to get the registration options -> RegistrationBeginLoading
   3. Create the public key with provided resgirationOptions in js-land: navigator.credentials.create() -> CreatingCredential | FailedCreatingPasskey String
      No Created status as we immediately go into next step:
   4. Call the BE /passkeys/registration/complete to verify and save the public key in the database -> RegistrationComplete{Loading,Failed,Loaded}
-}


type PasskeyRegistration
    = CheckingSupport
    | Supported
    | NotSupported
      -- GET /rest/passkeys/registration/begin
    | RegistrationBeginFailed Api.ServerError
    | RegistrationBeginLoading
      -- creating passkey in js-land
    | CreatingCredential
    | FailedCreatingPasskey String
      -- POST /rest/passkeys/registration/complete
    | RegistrationCompleteLoading
    | RegistrationCompleteFailed Api.ServerError
    | RegistrationCompleteLoaded RegistrationVerification


type alias RegistrationOptions =
    Encode.Value


type alias RegistrationVerification =
    Encode.Value


type alias AuthOptions =
    Encode.Value


type alias AuthVerification =
    Encode.Value


type PasskeyAuthentication
    = NotRequested
      -- POST /passkeys/authentication/begin with username from profile
    | AuthBeginLoading
    | AuthBeginFailed Api.ServerError
      -- Get passkey in js-land
    | GettingCredential
    | FailedGettingCredential String
    | AuthCompleteLoading
    | AuthCompleteFailed Api.ServerError
    | AuthCompleteLoaded AuthVerification


type Status a
    = Loading
    | Loaded a
    | Failed Api.ServerError


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , profile = Loading
      , registeredPasskeys = Loading
      , passkeyRegistration = CheckingSupport
      , passkeyAuthentication = NotRequested
      }
    , Cmd.batch
        [ Passkey.fetch LoadedProfile
        , Passkey.fetchPasskeys LoadedPasskeys
        , sendCheckPasskeySupportMsg
        ]
    )


view : Model -> { title : String, stickyContent : Element msg, content : Element Msg }
view model =
    { title = "Min profil"
    , stickyContent = Element.none
    , content =
        column [ alignLeft, spacing 20, padding 10, Region.mainContent ]
            [ row [ Font.light, Font.size Palette.xxLarge ] [ text "Min profil" ]
            , column [ spacing 10 ]
                [ viewRegisteredPasskeys model.registeredPasskeys
                , row [ spacing 20, width fill ]
                    [ viewPasskeyCreation model.passkeyRegistration
                    , viewPasskeyAuthentication model.passkeyAuthentication
                    ]
                ]
            , row [] [ viewLogoutButton ]
            ]
    }


viewLogoutButton : Element Msg
viewLogoutButton =
    let
        icon =
            FeatherIcons.logOut |> FeatherIcons.toHtml [] |> Element.html
    in
    el
        [ width <| Element.px 130
        , Background.color Palette.blush
        , Border.rounded 2
        , padding 10
        , Font.color Palette.white
        ]
        (Input.button [] { onPress = Just LogoutBtnPressed, label = row [] [ icon, text "Logga ut" ] })


viewRegisteredPasskeys : Status (List Passkey) -> Element Msg
viewRegisteredPasskeys passkeyStatus =
    let
        rmIcon =
            FeatherIcons.x |> FeatherIcons.toHtml [] |> Element.html

        formatDate =
            String.slice 0 16 >> String.replace "T" " "
    in
    case passkeyStatus of
        Loading ->
            Element.html Loading.animation

        Failed err ->
            Api.viewServerError "Något gick fel när passkeys skulle laddas" err

        Loaded ps ->
            column [ spacing 10 ]
                [ el [ Font.light, Font.size Palette.large ] (text "Registrerade passkeys")
                , Element.table [ width fill, spacingXY 10 0 ]
                    { data = ps
                    , columns =
                        [ { header = el [ Font.bold ] (text "Skapad på enhet")
                          , width = fill
                          , view = .name >> text
                          }
                        , { header = el [ Font.bold ] (text "ID")
                          , width = fill
                          , view = .credentialId >> text
                          }
                        , { header = el [ Font.bold ] (text "Datum skapad")
                          , width = fill
                          , view = .createdAt >> formatDate >> text
                          }
                        , { header = el [ Font.bold ] (text "Senast använd")
                          , width = fill
                          , view = .lastUsedAt >> Maybe.withDefault "" >> formatDate >> text
                          }
                        , { header = el [ Font.bold ] (text "Ta bort")
                          , width = fill
                          , view =
                                \p -> row [] [ Input.button [] { onPress = Just (RmPasskeyBtnPressed p.id), label = row [] [ rmIcon ] } ]
                          }
                        ]
                    }
                ]


viewPasskeyCreation : PasskeyRegistration -> Element Msg
viewPasskeyCreation passkeySupport =
    let
        createIcon =
            FeatherIcons.plus |> FeatherIcons.toHtml [] |> Element.html
    in
    case passkeySupport of
        CheckingSupport ->
            Element.none

        NotSupported ->
            text "Passkeys stöds inte på denna enhet. 😢"

        Supported ->
            row [ Element.alignTop ]
                [ Input.button
                    [ width fill, Background.color Palette.green, Border.rounded 2, padding 10, Font.color Palette.white ]
                    { onPress = Just CreatePasskeyPressed
                    , label = row [] [ createIcon, text "Skapa en ny passkey" ]
                    }
                ]

        RegistrationBeginLoading ->
            Element.html Loading.animation

        RegistrationBeginFailed err ->
            viewServerError "" err

        CreatingCredential ->
            Element.none

        FailedCreatingPasskey err ->
            column [ width fill ]
                [ paragraph [] [ text "💥 Något gick fel när passkey skulle skapas: " ]
                , paragraph [ Font.family [ Font.typeface "Courier New", Font.monospace ] ] [ text err ]
                ]

        RegistrationCompleteLoading ->
            Element.html Loading.animation

        RegistrationCompleteLoaded _ ->
            row
                [ Border.width 1
                , Border.rounded 2
                , Border.color Palette.darkGrey
                , padding 10
                ]
                [ FeatherIcons.check |> FeatherIcons.toHtml [] |> Element.html, text " Passkey skapad!" ]

        RegistrationCompleteFailed err ->
            viewServerError "posting to /complete failed" err


authIcon : Element Msg
authIcon =
    FeatherIcons.key |> FeatherIcons.toHtml [] |> Element.html


viewPasskeyAuthentication : PasskeyAuthentication -> Element Msg
viewPasskeyAuthentication auth =
    case auth of
        NotRequested ->
            row []
                [ Input.button
                    [ width fill, Background.color Palette.green, Border.rounded 2, padding 10, Font.color Palette.white ]
                    { onPress = Just AuthPasskeyPressed
                    , label = row [] [ authIcon, text "Autentisera med passkey" ]
                    }
                ]

        AuthBeginLoading ->
            Element.none

        AuthBeginFailed err ->
            viewServerError "Har du valt rätt passkey att autentisera med?" err

        GettingCredential ->
            Element.none

        FailedGettingCredential err ->
            column [ width fill ]
                [ paragraph [] [ text "💥 Något gick fel när passkey skulle hämtas: " ]
                , paragraph [ Font.family [ Font.typeface "Courier New", Font.monospace ] ] [ text err ]
                ]

        AuthCompleteLoading ->
            Element.html Loading.animation

        AuthCompleteFailed err ->
            viewServerError "Har du valt rätt passkey att autentisera med?" err

        AuthCompleteLoaded _ ->
            row
                [ Border.width 1
                , Border.rounded 2
                , Border.color Palette.darkGrey
                , padding 9
                ]
                [ FeatherIcons.check |> FeatherIcons.toHtml [] |> Element.html, text " Autentisering lyckades!" ]


type Msg
    = LoadedProfile (Result Api.ServerError Profile)
    | PortMsg Decode.Value
    | LoadedPasskeys (Result Api.ServerError (List Passkey))
    | CreatePasskeyPressed
    | LoadedRegistrationBegin (Result Api.ServerError RegistrationOptions)
    | LoadedRegistrationComplete (Result Api.ServerError Encode.Value)
    | AuthPasskeyPressed
    | LoadedAuthenticationBegin (Result Api.ServerError AuthOptions)
    | LoadedAuthenticationComplete (Result Api.ServerError Encode.Value)
    | RmPasskeyBtnPressed Int
    | DeletePasskeyComplete (Result Api.ServerError ())
    | LogoutBtnPressed
    | LogoutComplete (Result Api.ServerError ())


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        handleError err updates =
            case err of
                Api.Unauthorized ->
                    ( model, Route.pushUrl (Session.navKey (toSession model)) Route.Login )

                _ ->
                    updates
    in
    case msg of
        LoadedProfile (Ok profile) ->
            ( { model | profile = Loaded profile }, Cmd.none )

        LoadedProfile (Err err) ->
            ( { model | profile = Failed err }, Cmd.none )

        PortMsg m ->
            case Decode.decodeValue Passkey.passkeyPortMsgDecoder m of
                Err _ ->
                    ( model, Cmd.none )

                Ok (Passkey.PasskeySupported supported) ->
                    if supported then
                        ( { model | passkeyRegistration = Supported }, Cmd.none )

                    else
                        ( { model | passkeyRegistration = NotSupported }, Cmd.none )

                Ok (Passkey.PasskeyCreationFailed errStr) ->
                    ( { model | passkeyRegistration = FailedCreatingPasskey errStr }, Cmd.none )

                Ok (Passkey.PasskeyCreated credential name) ->
                    ( { model | passkeyRegistration = RegistrationCompleteLoading }, Passkey.passkeyRegistrationComplete credential name LoadedRegistrationComplete )

                Ok (Passkey.PasskeyRetrieved passkey) ->
                    ( { model | passkeyAuthentication = AuthCompleteLoading }, Passkey.passkeyAuthenticationComplete passkey LoadedAuthenticationComplete )

                Ok (Passkey.PasskeyRetrievalFailed err) ->
                    ( { model | passkeyAuthentication = FailedGettingCredential err }, Cmd.none )

        LoadedPasskeys (Ok ps) ->
            ( { model | registeredPasskeys = Loaded ps }, Cmd.none )

        LoadedPasskeys (Err err) ->
            handleError err ( { model | registeredPasskeys = Failed err }, Cmd.none )

        CreatePasskeyPressed ->
            ( { model | passkeyRegistration = RegistrationBeginLoading }, Passkey.passkeyRegistrationBegin LoadedRegistrationBegin )

        LoadedRegistrationBegin (Ok options) ->
            ( { model | passkeyRegistration = CreatingCredential }, sendCreatePasskeyMsg options )

        LoadedRegistrationBegin (Err err) ->
            handleError err ( { model | passkeyRegistration = RegistrationBeginFailed err }, Cmd.none )

        LoadedRegistrationComplete (Ok response) ->
            ( { model | passkeyRegistration = RegistrationCompleteLoaded response }, Passkey.fetchPasskeys LoadedPasskeys )

        LoadedRegistrationComplete (Err err) ->
            handleError err ( { model | passkeyRegistration = RegistrationCompleteFailed err }, Cmd.none )

        AuthPasskeyPressed ->
            case model.profile of
                Loaded profile ->
                    ( { model | passkeyAuthentication = AuthBeginLoading }, Passkey.passkeyAuthenticationBegin (Just profile.userName) LoadedAuthenticationBegin )

                _ ->
                    ( model, Cmd.none )

        LoadedAuthenticationBegin (Ok options) ->
            ( { model | passkeyAuthentication = GettingCredential }, Passkey.sendGetPasskeyMsg options )

        LoadedAuthenticationBegin (Err err) ->
            handleError err ( { model | passkeyAuthentication = AuthBeginFailed err }, Cmd.none )

        LoadedAuthenticationComplete (Ok response) ->
            ( { model | passkeyAuthentication = AuthCompleteLoaded response }, Passkey.fetchPasskeys LoadedPasskeys )

        LoadedAuthenticationComplete (Err err) ->
            handleError err ( { model | passkeyAuthentication = AuthCompleteFailed err }, Cmd.none )

        RmPasskeyBtnPressed id ->
            ( model, Passkey.deletePasskey id DeletePasskeyComplete )

        DeletePasskeyComplete (Ok ()) ->
            ( model, Passkey.fetchPasskeys LoadedPasskeys )

        DeletePasskeyComplete (Err err) ->
            handleError err ( model, Cmd.none )

        LogoutBtnPressed ->
            ( model, Passkey.logout LogoutComplete )

        LogoutComplete (Ok _) ->
            ( model, Route.pushUrl (Session.navKey (toSession model)) Route.Login )

        LogoutComplete (Err _) ->
            ( model, Cmd.none )


toSession : Model -> Session
toSession model =
    model.session


subscriptions : Model -> Sub Msg
subscriptions _ =
    Passkey.subscribe PortMsg

