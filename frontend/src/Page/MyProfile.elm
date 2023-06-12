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
import Palette
import Route
import Session exposing (Session)
import String.Verify
import Url.Builder
import Verify




-- TODO show /me: {"me":{"user_name":"familjen","role":"customer","email":null,"id":3}}
-- VIEW


type alias Model =
    { session : Session }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session }, Cmd.none )


view : Model -> { title : String, stickyContent : Element msg, content : Element Msg }
view model =
    { title = "Min profil"
    , stickyContent = Element.none
    , content =
        column
            [ Region.mainContent
            , width (fill |> Element.maximum 400)
            , centerX
            , spacing 10
            , padding 10
            ]
            [ row [ Font.heavy, Font.size Palette.xxLarge ] [ text "Min profil" ]
            , row [width fill, spacing 30 ] [el [Font.heavy] (text "Användarnamn"), el [] (text "axel")]
            , row [width fill, spacing 30 ] [el [Font.heavy] (text "Email"), el [] (text "axl.larsson@gmail.com")]
            ]
    }


type Msg
    = Noop


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ session } as model) =
    ( model, Cmd.none )


toSession : Model -> Session
toSession model =
    model.session
