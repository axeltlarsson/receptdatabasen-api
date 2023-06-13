module Page.MyProfile exposing (Model, Msg, init, toSession, update, view)

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



-- TODO show /me: {"me":{"user_name":"familjen","role":"customer","email":null,"id":3}}


type alias Model =
    { session : Session, profile : Status Profile }


type Status profile
    = Loading
    | Loaded Profile
    | Failed Api.ServerError


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session, profile = Loading }, fetch LoadedProfile )


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
                viewProfile profile
    }


viewProfile : Profile -> Element msg
viewProfile profile =
    column
        [ Region.mainContent
        , width (fill |> Element.maximum 400)
        , centerX
        , spacing 10
        , padding 10
        ]
        [ row [ Font.heavy, Font.size Palette.xxLarge ] [ text "Min profil" ]
        , row [ width fill, spacing 30 ] [ el [ Font.heavy ] (text "Användarnamn"), el [] (text profile.userName) ]
        , row [ width fill, spacing 30 ] [ el [ Font.heavy ] (text "Email"), el [] (text (Maybe.withDefault "ej satt" profile.email)) ]
        , row [ width fill, spacing 30 ] [ el [ Font.heavy ] (text "Roll"), el [] (text profile.role) ]
        , row [ width fill, spacing 30 ] [ el [ Font.heavy ] (text "ID"), el [] (profile.id |> String.fromInt |> text) ]
        ]


type Msg
    = LoadedProfile (Result Api.ServerError Profile)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedProfile (Ok profile) ->
            ( { model | profile = Loaded profile }, Cmd.none )

        LoadedProfile (Err error) ->
            ( { model | profile = Failed error }, Cmd.none )


toSession : Model -> Session
toSession model =
    model.session
