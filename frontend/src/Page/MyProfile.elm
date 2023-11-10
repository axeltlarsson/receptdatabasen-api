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
    , passkeyCreation : PasskeyCreation
    }


type PasskeyCreation
    = CheckingSupport
    | Supported
      -- RegistrationOptions from /rest/rpc/passkeys/registration/begin
    | RegistrationOptionsStatus (Status RegistrationOptions)
    | CreatingCredential
    | Created Credential
    | FailedCreatingPasskey String
    | NotSupported



-- Passed directly to Port - no need to further decode value


type alias RegistrationOptions =
    Encode.Value


type Status a
    = Loading
    | Loaded a
    | Failed Api.ServerError


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session, profile = Loading, registeredPasskeys = Loading, passkeyCreation = CheckingSupport }
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
            , viewPasskeyCreation model.passkeyCreation
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
                      , view = .publicKey >> shortenPublicKey >> text
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


viewPasskeyCreation : PasskeyCreation -> Element Msg
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

        RegistrationOptionsStatus Loading ->
            text "🚧 laddar options från server"

        RegistrationOptionsStatus (Loaded options) ->
            text "✅ loaded options från server"

        RegistrationOptionsStatus (Failed err) ->
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

        Created credential ->
            viewCredential credential


type Msg
    = LoadedProfile (Result Api.ServerError Profile)
    | PortMsg Decode.Value
    | LoadedPasskeys (Result Api.ServerError (List Passkey))
    | CreatePasskeyPressed
    | LoadedRegistrationOptions (Result Api.ServerError RegistrationOptions)


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
                        ( { model | passkeyCreation = Supported }, Cmd.none )

                    else
                        ( { model | passkeyCreation = NotSupported }, Cmd.none )

                Ok (PasskeyCreationFailed errStr) ->
                    ( { model | passkeyCreation = FailedCreatingPasskey errStr }, Cmd.none )

                Ok (PasskeyCreated credential) ->
                    Debug.log (Debug.toString credential) ( { model | passkeyCreation = Created credential }, Cmd.none )

        LoadedPasskeys (Ok ps) ->
            ( { model | registeredPasskeys = Loaded ps }, Cmd.none )

        LoadedPasskeys (Err err) ->
            ( { model | registeredPasskeys = Failed err }, Cmd.none )

        CreatePasskeyPressed ->
            ( { model | passkeyCreation = RegistrationOptionsStatus Loading }, Profile.fetchRegistrationOptions LoadedRegistrationOptions )

        LoadedRegistrationOptions (Ok options) ->
            ( { model | passkeyCreation = RegistrationOptionsStatus (Loaded options) }, passkeyPortSender (createPasskeyMsg options) )

        LoadedRegistrationOptions (Err err) ->
            ( { model | passkeyCreation = RegistrationOptionsStatus (Failed err) }, Cmd.none )


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
    | PasskeyCreated Credential
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
                        Decode.map PasskeyCreated (Decode.field "passkey" credentialDecoder)

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
