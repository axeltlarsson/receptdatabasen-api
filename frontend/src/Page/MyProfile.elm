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
import Profile exposing (Profile, fetch)
import Route
import Session exposing (Session)
import String.Verify
import Url.Builder
import Verify


type alias Model =
    { session : Session, profile : Status Profile }


type Status a
    = Loading
    | Loaded a
    | Failed Api.ServerError


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session, profile = Loading }
    , Cmd.batch
        [ fetch LoadedProfile
        , passkeyPortSender checkPasskeySupport
        ]
    )


checkPasskeySupport : Encode.Value
checkPasskeySupport =
    Encode.object [ ( "type", Encode.string "checkPasskeySupport" ) ]


view : Model -> { title : String, stickyContent : Element msg, content : Element Msg }
view model =
    { title = "Min profil"
    , stickyContent = Element.none
    , content =
        case model.profile of
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
                    , row [] [ viewProfile profile ]
                    , row [ Font.light, Font.size Palette.large ] [ text "Passkeys" ]
                    , row [] [ viewPasskeys ]
                    ]
    }


viewProfile : Profile -> Element msg
viewProfile profile =
    column
        []
        [ row [ width fill, spacing 30 ] [ el [ Font.heavy ] (text "Användarnamn"), el [] (text profile.userName) ]
        , row [ width fill, spacing 30 ] [ el [ Font.heavy ] (text "Email"), el [] (text (Maybe.withDefault "ej satt" profile.email)) ]
        , row [ width fill, spacing 30 ] [ el [ Font.heavy ] (text "Roll"), el [] (text profile.role) ]
        , row [ width fill, spacing 30 ] [ el [ Font.heavy ] (text "ID"), el [] (profile.id |> String.fromInt |> text) ]
        ]


port passkeyPortSender : Encode.Value -> Cmd msg


port passkeyPortReceiver : (Decode.Value -> msg) -> Sub msg


passkeys : List { publicKey : String, device : String }
passkeys =
    [ { publicKey = "131321", device = "my Mac" }
    , { publicKey = "789712", device = "my phone" }
    ]


viewPasskeys : Element Msg
viewPasskeys =
    Element.table [ width fill, spacingXY 10 0 ]
        { data = passkeys
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


type Msg
    = LoadedProfile (Result Api.ServerError Profile)
    | PortMsg Decode.Value


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedProfile (Ok profile) ->
            ( { model | profile = Loaded profile }, Cmd.none )

        LoadedProfile (Err error) ->
            ( { model | profile = Failed error }, Cmd.none )

        PortMsg m ->
            case Decode.decodeValue passkeyPortMsgDecoder m of
                Err err ->
                    Debug.log (Debug.toString err) ( model, Cmd.none )

                Ok (PasskeySupported supported) ->
                    Debug.log (Debug.toString supported) ( model, Cmd.none )


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
subscriptions model =
    passkeyPortReceiver PortMsg
