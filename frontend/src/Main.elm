module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Url
import Url.Parser exposing ((</>), (<?>), Parser, int, map, oneOf, s, string)
import Url.Parser.Query as Query



-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



--- ROUTER


routeParser : Parser (Page -> a) a
routeParser =
    oneOf
        [ map Recipe (s "recipes" </> int)
        , map RecipeQuery (s "recipes" <?> Query.string "search")
        ]


stepUrl : Url.Url -> Model -> ( Model, Cmd Msg )
stepUrl url model =
    case Url.Parser.parse routeParser url of
        Just page ->
            ( { model | page = page }
            , Cmd.none
            )

        Nothing ->
            ( { model | page = NotFound }
            , Cmd.none
            )



-- MODEL


type alias Model =
    { key : Nav.Key
    , page : Page
    }


type Page
    = Recipe Int
    | RecipeQuery (Maybe String)
    | NotFound


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    stepUrl url
        { key = key
        , page = RecipeQuery Nothing
        }



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            stepUrl url model



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Browser.Document Msg
view model =
    case model.page of
        NotFound ->
            { title = "Not Found"
            , body =
                [ text "Not found"
                , viewLinks
                ]
            }

        Recipe i ->
            { title = "Recipe " ++ String.fromInt i
            , body =
                [ h1 [] [ text (String.fromInt i) ]
                , viewLinks
                ]
            }

        RecipeQuery search ->
            { title = "Recipe search"
            , body =
                [ h1 [] [ text "searching" ]
                , viewLinks
                ]
            }


viewLinks : Html msg
viewLinks =
    ul []
        [ viewLink "/recipes"
        , viewLink "/recipes/1"
        ]


viewLink : String -> Html msg
viewLink path =
    li [] [ a [ href path ] [ text path ] ]
