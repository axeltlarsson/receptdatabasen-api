module Page.MyProfile exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Api exposing (viewServerError)
import Element
    exposing
        ( Element
        , alignRight
        , centerX
        , column
        , el
        , fill
        , padding
        , paddingEach
        , paragraph
        , row
        , spacing
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
import Passkey exposing (Passkey, Profile)
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
        , Passkey.sendCheckPasskeySupportMsg
        ]
    )


view : Model -> { title : String, stickyContent : Element msg, content : Element Msg }
view model =
    let
        device =
            Session.device model.session

        responsiveLayout attrs contents =
            if phoneLayout device then
                column attrs contents

            else
                row attrs contents
    in
    { title = "Min profil"
    , stickyContent = Element.none
    , content =
        column [ centerX, spacing 20, padding 10, width (fill |> Element.maximum 700), Region.mainContent ]
            [ column [ spacing 10, width fill, centerX ]
                [ viewProfile model.profile
                , viewRegisteredPasskeys model.registeredPasskeys device
                , responsiveLayout [ spacing 20 ]
                    [ viewPasskeyCreation model.passkeyRegistration
                    , viewPasskeyAuthentication model.passkeyAuthentication
                    ]
                ]
            , row [] [ viewLogoutButton ]
            ]
    }


viewProfile : Status Profile -> Element Msg
viewProfile profileStatus =
    case profileStatus of
        Loaded profile ->
            column
                [ Border.glow Palette.lightGrey 0.5
                , Background.color Palette.white
                , Border.rounded 2
                , paddingEach { left = 0, right = 0, top = 5, bottom = 5 }
                , centerX
                , spacing 5
                , padding 10
                , width (fill |> Element.maximum 700)
                ]
                [ row [ paddingEach { left = 0, right = 0, top = 0, bottom = 10 }, Font.extraLight, Font.size Palette.medium ] [ text "Kontouppgifter" ]
                , row [ spacing 5 ] [ el [ Font.extraLight ] (text "Användar-id"), profile.id |> String.fromInt |> text ]
                , row [ spacing 5 ] [ el [ Font.extraLight ] (text "Användarnamn"), profile.userName |> text ]
                , row [ spacing 5 ] [ el [ Font.extraLight ] (text "Email"), profile.email |> Maybe.withDefault "ej angiven" |> text ]
                ]

        _ ->
            Element.none


viewLogoutButton : Element Msg
viewLogoutButton =
    el
        [ width fill
        , Background.color Palette.blush
        , Border.rounded 2
        , padding 10
        , Font.color Palette.white
        ]
        (Input.button [] { onPress = Just LogoutBtnPressed, label = row [ spacing 10 ] [ wrapIcon FeatherIcons.logOut, text "Logga ut" ] })


wrapIcon : FeatherIcons.Icon -> Element msg
wrapIcon icon =
    el [ Element.centerX ]
        (icon |> FeatherIcons.withSize 26 |> FeatherIcons.withStrokeWidth 1 |> FeatherIcons.toHtml [] |> Element.html)


viewRegisteredPasskeys : Status (List Passkey) -> Element.Device -> Element Msg
viewRegisteredPasskeys passkeyStatus device =
    case passkeyStatus of
        Loading ->
            Element.html Loading.animation

        Failed err ->
            Api.viewServerError "Något gick fel när passkeys skulle laddas" err

        Loaded [] ->
            el [ Font.color Palette.nearBlack, Font.extraLight, padding 10 ] <| text "Inga passkeys har registrerats än"

        Loaded (p :: ps) ->
            viewResponsiveTable device (p :: ps)


phoneLayout { class, orientation } =
    case ( class, orientation ) of
        ( Element.Phone, Element.Portrait ) ->
            True

        _ ->
            False


viewResponsiveTable : Element.Device -> List Passkey -> Element Msg
viewResponsiveTable device passkeys =
    let
        formatDate =
            String.slice 0 16 >> String.replace "T" " "

        shortenId len id =
            String.left (len - 6) id ++ "..." ++ String.right 3 id

        responsiveId id =
            if phoneLayout device then
                shortenId 20 id

            else if String.length id > 40 then
                shortenId 40 id

            else
                id
    in
    column
        [ Border.glow Palette.lightGrey 0.5
        , Background.color Palette.white
        , Border.rounded 2
        , paddingEach { left = 0, right = 0, top = 5, bottom = 5 }
        , Font.color Palette.nearBlack
        , width fill
        ]
        (List.concat
            [ [ el [ padding 10, Font.extraLight, Font.size Palette.medium ] (text "Registrerade passkeys") ]
            , passkeys
                |> List.map
                    (\p ->
                        row [ width fill, spacing 10, padding 10 ]
                            [ wrapIcon FeatherIcons.key
                            , column [ spacing 10, width fill ]
                                [ el [ Font.semiBold ] (p.name |> text)
                                , row [ spacing 5 ]
                                    [ el [ Font.extraLight ] (text "ID")
                                    , p.credentialId |> responsiveId |> text |> el [ Font.family [ Font.monospace ] ]
                                    ]
                                , row [ spacing 5, Font.extraLight ]
                                    [ text "Skapad"
                                    , el [ Font.family [ Font.monospace ] ] (text (p.createdAt |> formatDate))
                                    ]
                                , row [ spacing 5, Font.extraLight ]
                                    [ text "Använd"
                                    , el [ Font.family [ Font.monospace ] ] (text (p.lastUsedAt |> Maybe.withDefault "" |> formatDate))
                                    ]
                                ]
                            , Input.button [ paddingEach { top = 0, left = 5, right = 10, bottom = 0 }, alignRight ]
                                { onPress = Just (RmPasskeyBtnPressed p.id), label = row [] [ wrapIcon FeatherIcons.x ] }
                            ]
                    )
            ]
        )


viewPasskeyCreation : PasskeyRegistration -> Element Msg
viewPasskeyCreation passkeySupport =
    let
        createIcon =
            wrapIcon FeatherIcons.plus
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
                [ wrapIcon FeatherIcons.check, text " Passkey skapad!" ]

        RegistrationCompleteFailed err ->
            viewServerError "posting to /complete failed" err


viewPasskeyAuthentication : PasskeyAuthentication -> Element Msg
viewPasskeyAuthentication auth =
    case auth of
        NotRequested ->
            row []
                [ Input.button
                    [ width fill, Background.color Palette.green, Border.rounded 2, padding 10, Font.color Palette.white ]
                    { onPress = Just AuthPasskeyPressed
                    , label = row [] [ wrapIcon FeatherIcons.key, text "Autentisera med passkey" ]
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
                [ wrapIcon FeatherIcons.check, text " Autentisering lyckades!" ]


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
            case Decode.decodeValue Passkey.portMsgDecoder m of
                Err err ->
                    ( { model | passkeyRegistration = FailedCreatingPasskey (Decode.errorToString err) }, Cmd.none )

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
            ( { model | passkeyRegistration = CreatingCredential }, Passkey.sendCreatePasskeyMsg options )

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
