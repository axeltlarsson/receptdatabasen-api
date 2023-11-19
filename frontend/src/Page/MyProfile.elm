port module Page.MyProfile exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Api exposing (ServerError, expectJsonWithBody, viewServerError)
import Element
    exposing
        ( Element
        , centerX
        , column
        , el
        , fill
        , padding
        , paddingEach
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
import Json.Decode as Decode exposing (field, string)
import Json.Encode as Encode
import Loading
import Palette
import Profile exposing (Passkey, Profile)
import Session exposing (Session)


type alias Model =
    { session : Session
    , profile : Status Profile
    , registeredPasskeys : Status (List Passkey)
    , passkeyRegistration : PasskeyRegistration
    }



{-
   Passkey registration requires a number of steps

   1. Check for client support -> `CheckingSupport` | `Supported` | `NotSupported`
   2. Call the BE /passkeys/registration/begin to get the registration options -> RegistrationBeginStatus (Status RegistrationOptions)
   3. Create the public key with provided resgirationOptions in js-land: navigator.credentials.create() -> CreatingCredential | FailedCreatingPasskey String
      No Created status as we immediately go into next step:
   4. Call the BE /passkeys/registration/complete to verify and save the public key in the database -> RegistrationCompleteStatus (Status x)
-}


type PasskeyRegistration
    = CheckingSupport
    | Supported
    | NotSupported
      -- /rest/passkeys/registration/begin TODO: don't need to have Loaded status (goes directly to creating credential
    | RegistrationBeginStatus (Status RegistrationOptions)
      -- creating passkey in js-land
    | CreatingCredential
    | FailedCreatingPasskey String
      -- /rest/passkeys/registration/complete
    | RegistrationCompleteStatus (Status VerificationResponse)





type alias RegistrationOptions =
    -- Passed directly to Port - no need to further decode value
    Encode.Value


type alias VerificationResponse =
    Encode.Value


type Status a
    = Loading
    | Loaded a
    | Failed Api.ServerError


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session, profile = Loading, registeredPasskeys = Loading, passkeyRegistration = CheckingSupport }
    , Cmd.batch
        [ Profile.fetch LoadedProfile
        , Profile.fetchPasskeys LoadedPasskeys
        , passkeyPortSender checkPasskeySupport
        ]
    )


view : Model -> { title : String, stickyContent : Element msg, content : Element Msg }
view model =
    { title = "Min profil"
    , stickyContent = Element.none
    , content =
        column [ centerX ]
            [ viewProfile model.profile
            , viewRegisteredPasskeys model.registeredPasskeys
            , viewPasskeyCreation model.passkeyRegistration
            ]
    }


viewProfile : Status Profile -> Element msg
viewProfile profileStatus =
    case profileStatus of
        Loading ->
            Element.html Loading.animation

        Failed err ->
            Api.viewServerError "Något gick fel när profilen skulle laddas" err

        Loaded profile ->
            column
                [ Region.mainContent
                , width (fill |> Element.maximum 600)
                , centerX
                , spacing 10
                , padding 10
                ]
                [ row [ Font.light, Font.size Palette.xxLarge ] [ text "Min profil" ]
                , column
                    []
                    [ row [ width fill, spacing 30 ] [ el [ Font.heavy ] (text "Användarnamn"), el [] (text profile.userName) ]
                    , row [ width fill, spacing 30 ] [ el [ Font.heavy ] (text "Email"), el [] (text (Maybe.withDefault "ej satt" profile.email)) ]
                    , row [ width fill, spacing 30 ] [ el [ Font.heavy ] (text "Roll"), el [] (text profile.role) ]
                    , row [ width fill, spacing 30 ] [ el [ Font.heavy ] (text "ID"), el [] (profile.id |> String.fromInt |> text) ]
                    ]
                ]


shortenPublicKey : String -> String
shortenPublicKey key =
    String.left 20 key ++ "..." ++ String.right 10 key


viewRegisteredPasskeys : Status (List Passkey) -> Element Msg
viewRegisteredPasskeys passkeyStatus =
    case passkeyStatus of
        Loading ->
            Element.html Loading.animation

        Failed err ->
            Api.viewServerError "Något gick fel när passkeys skulle laddas" err

        Loaded ps ->
            Element.table [ width fill, spacingXY 10 0 ]
                { data = ps
                , columns =
                    [ { header = el [ Font.bold ] (text "id")
                      , width = fill
                      , view = .id >> String.fromInt >> text
                      }
                    , { header = el [ Font.bold ] (text "public key")
                      , width = fill
                      , view = .data >> shortenPublicKey >> text
                      }
                    , { header = el [ Font.bold ] (text "created at")
                      , width = fill
                      , view = .createdAt >> text
                      }
                    , { header = el [ Font.bold ] (text "remove")
                      , width = fill
                      , view = \_ -> text "Ta bort"
                      }
                    ]
                }


viewPasskeyCreation : PasskeyRegistration -> Element Msg
viewPasskeyCreation passkeySupport =
    case passkeySupport of
        CheckingSupport ->
            Element.none

        NotSupported ->
            text "passkeys cannot be created on this device"

        Supported ->
            row [ centerX, width (Element.px 200) ]
                [ Input.button
                    [ width fill, Background.color Palette.green, Border.rounded 2, padding 10, Font.color Palette.white ]
                    { onPress = Just CreatePasskeyPressed
                    , label = el [ centerX ] (text "Skapa en ny passkey")
                    }
                ]

        RegistrationBeginStatus Loading ->
            text "🚧 laddar options från server"

        RegistrationBeginStatus (Loaded _) ->
            -- TODO: not needed
            Element.none

        RegistrationBeginStatus (Failed err) ->
            viewServerError "" err

        CreatingCredential ->
            row [ centerX ]
                [ text "Skapar passkey..."
                ]

        FailedCreatingPasskey err ->
            column [ centerX ]
                [ paragraph [] [ text "💥 Något gick fel när passkey skulle skapas: " ]
                , paragraph [ Font.family [ Font.typeface "Courier New", Font.monospace ] ] [ text err ]
                ]

        RegistrationCompleteStatus Loading ->
            text "posting to /complete"

        RegistrationCompleteStatus (Loaded json) ->
            text "posting to /complete done!"

        RegistrationCompleteStatus (Failed err) ->
            viewServerError "posting to /complete failed" err


type Msg
    = LoadedProfile (Result Api.ServerError Profile)
    | PortMsg Decode.Value
    | LoadedPasskeys (Result Api.ServerError (List Passkey))
    | CreatePasskeyPressed
    | LoadedRegistrationBegin (Result Api.ServerError RegistrationOptions)
    | LoadedRegistrationComplete (Result Api.ServerError Encode.Value)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedProfile (Ok profile) ->
            ( { model | profile = Loaded profile }, Cmd.none )

        LoadedProfile (Err err) ->
            ( { model | profile = Failed err }, Cmd.none )

        PortMsg m ->
            case Decode.decodeValue passkeyPortMsgDecoder m of
                Err err ->
                    Debug.log (Debug.toString err ++ " error decodeValue") ( model, Cmd.none )

                Ok (PasskeySupported supported) ->
                    if supported then
                        ( { model | passkeyRegistration = Supported }, Cmd.none )

                    else
                        ( { model | passkeyRegistration = NotSupported }, Cmd.none )

                Ok (PasskeyCreationFailed errStr) ->
                    ( { model | passkeyRegistration = FailedCreatingPasskey errStr }, Cmd.none )

                Ok (PasskeyCreated credential) ->
                    Debug.log (Debug.toString credential) ( { model | passkeyRegistration = RegistrationCompleteStatus Loading }, Profile.passkeyRegistrationComplete credential LoadedRegistrationComplete )

        LoadedPasskeys (Ok ps) ->
            ( { model | registeredPasskeys = Loaded ps }, Cmd.none )

        LoadedPasskeys (Err err) ->
            ( { model | registeredPasskeys = Failed err }, Cmd.none )

        CreatePasskeyPressed ->
            ( { model | passkeyRegistration = RegistrationBeginStatus Loading }, Profile.passkeyRegistrationBegin LoadedRegistrationBegin )

        LoadedRegistrationBegin (Ok options) ->
            ( { model | passkeyRegistration = RegistrationBeginStatus (Loaded options) }, passkeyPortSender (createPasskeyMsg options) )

        LoadedRegistrationBegin (Err err) ->
            ( { model | passkeyRegistration = RegistrationBeginStatus (Failed err) }, Cmd.none )

        LoadedRegistrationComplete (Ok response) ->
            ( { model | passkeyRegistration = RegistrationCompleteStatus (Loaded response) }, Cmd.none )

        LoadedRegistrationComplete (Err err) ->
            ( { model | passkeyRegistration = RegistrationCompleteStatus (Failed err) }, Cmd.none )


port passkeyPortSender : Encode.Value -> Cmd msg


port passkeyPortReceiver : (Decode.Value -> msg) -> Sub msg


checkPasskeySupport : Encode.Value
checkPasskeySupport =
    Encode.object [ ( "type", Encode.string "checkPasskeySupport" ) ]


createPasskeyMsg : RegistrationOptions -> Encode.Value
createPasskeyMsg options =
    Encode.object [ ( "type", Encode.string "createPasskey" ), ( "options", options ) ]


type PasskeyPortMsg
    = PasskeySupported Bool
    | PasskeyCreated Decode.Value
    | PasskeyCreationFailed String


type alias Credential =
    { id : String
    , response : Response
    }


type alias Response =
    { attestationObject : String
    , clientDataJSON : String
    }


viewCredential : Credential -> Element msg
viewCredential cred =
    column []
        [ row []
            [ text "id"
            , text "response.attestationObject"
            , text "response.clientDataJSON"
            ]
        , row []
            [ text cred.id
            , cred.response.attestationObject |> shortenPublicKey >> text
            , cred.response.clientDataJSON |> shortenPublicKey >> text
            ]
        ]



-- TODO: can I use Decode.value here? https://package.elm-lang.org/packages/elm/json/latest/Json-Decode#value


credentialDecoder : Decode.Decoder Credential
credentialDecoder =
    Decode.map2 Credential
        (field "id" string)
        (field "response"
            (Decode.map2 Response
                (field "attestationObject" string)
                (field "clientDataJSON" string)
            )
        )


passkeyPortMsgDecoder : Decode.Decoder PasskeyPortMsg
passkeyPortMsgDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\t ->
                case t of
                    "passkeySupported" ->
                        Decode.map PasskeySupported (Decode.field "passkeySupport" Decode.bool)

                    "passkeyCreated" ->
                        Decode.map PasskeyCreated (Decode.field "passkey" Decode.value)

                    "error" ->
                        Decode.map PasskeyCreationFailed (Decode.field "error" Decode.string)

                    _ ->
                        Decode.fail ("trying to decode port passkeyPortMsg but " ++ t ++ " is not supported")
            )


toSession : Model -> Session
toSession model =
    model.session


subscriptions : Model -> Sub Msg
subscriptions _ =
    passkeyPortReceiver PortMsg
