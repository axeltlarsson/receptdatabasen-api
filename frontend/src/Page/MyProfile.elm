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
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import FeatherIcons
import Form exposing (errorBorder, onEnter, viewValidationError)
import Http
import Json.Decode as Decode exposing (field, string)
import Json.Encode as Encode
import Loading
import Palette
import Profile exposing (Passkey, Profile)
import Route
import Session exposing (Session)
import String.Verify
import Url.Builder
import Verify


type alias Model =
    { session : Session
    , profile : Status Profile
    , registeredPasskeys : Status (List Passkey)
    , passkeySupport : PasskeySupport
    }


type PasskeySupport
    = CheckingSupport
    | Supported
    | NotSupported


type Status a
    = Loading
    | Loaded a
    | Failed Api.ServerError


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session, profile = Loading, registeredPasskeys = Loading, passkeySupport = CheckingSupport }
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
        column []
            [ viewProfile model.profile
            , viewRegisteredPasskeys model.registeredPasskeys
            , viewPasskeyCreation model.passkeySupport
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
                    [ { header = el [ Font.bold ] (text "public key")
                      , width = fill
                      , view = .device >> text
                      }
                    , { header = el [ Font.bold ] (text "device")
                      , width = fill
                      , view = .device >> text
                      }
                    , { header = el [ Font.bold ] (text "remove")
                      , width = fill
                      , view = \_ -> text "Ta bort"
                      }
                    ]
                }


viewPasskeyCreation : PasskeySupport -> Element msg
viewPasskeyCreation passkeySupport =
    case passkeySupport of
        CheckingSupport ->
            Element.none

        NotSupported ->
            text "passkeys cannot be created on this device"

        Supported ->
            text "You Can Create Passkeys on this Device!"


type Msg
    = LoadedProfile (Result Api.ServerError Profile)
    | PortMsg Decode.Value
    | LoadedPasskeys (Result Api.ServerError (List Passkey))


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
                        ( { model | passkeySupport = Supported }, Cmd.none )

                    else
                        ( { model | passkeySupport = NotSupported }, Cmd.none )

        LoadedPasskeys (Ok ps) ->
            ( { model | registeredPasskeys = (Loaded ps) }, Cmd.none )

        LoadedPasskeys (Err err) ->
            ( { model | registeredPasskeys = (Failed err) }, Cmd.none )


port passkeyPortSender : Encode.Value -> Cmd msg


port passkeyPortReceiver : (Decode.Value -> msg) -> Sub msg


checkPasskeySupport : Encode.Value
checkPasskeySupport =
    Encode.object [ ( "type", Encode.string "checkPasskeySupport" ) ]


type PasskeyPortMsg
    = PasskeySupported Bool


passkeyPortMsgDecoder : Decode.Decoder PasskeyPortMsg
passkeyPortMsgDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\t ->
                case t of
                    "passkeySupported" ->
                        Decode.map PasskeySupported (Decode.field "passkeySupport" Decode.bool)

                    _ ->
                        Decode.fail ("trying to decode port passkeyPortMsg but " ++ t ++ " is not supported")
            )


toSession : Model -> Session
toSession model =
    model.session


subscriptions : Model -> Sub Msg
subscriptions _ =
    passkeyPortReceiver PortMsg
