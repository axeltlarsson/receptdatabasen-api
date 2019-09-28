module Page.RecipeList exposing (Model, Msg, Status, init, toSession, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as Decoder exposing (Decoder, list)
import Recipe exposing (Preview, Recipe, previewDecoder)
import Recipe.Slug as Slug exposing (Slug)
import Route exposing (Route)
import Session exposing (Session)
import Url
import Url.Builder



-- MODEL


type alias Model =
    { session : Session, recipes : Status (List (Recipe Preview)) }


type Status recipes
    = Loading
    | Loaded recipes
    | Failed Http.Error


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , recipes = Loading
      }
    , getRecipes
    )



-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    case model.recipes of
        Loading ->
            { title = "Recipes"
            , content = text ""
            }

        Failed err ->
            { title = "Failed to load"
            , content = viewError err
            }

        Loaded recipes ->
            { title = "Recipes"
            , content =
                div [ class "row" ] (List.map viewPreview recipes)
            }


viewPreview : Recipe Preview -> Html Msg
viewPreview recipe =
    let
        { title, description, id, createdAt } =
            Recipe.metadata recipe

        titleStr =
            Slug.toString title
    in
    div [ class "col-4" ]
        [ a [ Route.href (Route.Recipe title) ]
            [ case id of
                23 ->
                    viewPreviewWithoutImage titleStr id description createdAt

                _ ->
                    viewPreviewWithImage titleStr id description createdAt
            ]
        ]


viewPreviewWithImage : String -> Int -> String -> String -> Html Msg
viewPreviewWithImage title id description createdAt =
    div [ class "card", class "u-flex", class "u-flex-column", class "h-90" ]
        [ div [ class "card-container" ]
            [ div [ class "card-image", style "background-image" (imgUrl id) ] []
            , div [ class "title-container" ]
                [ p [ class "title" ] [ text title ]

                -- , span [ class "subtitle" ] [ text "by me" ]
                ]
            ]
        , div [ class "content", style "color" "black" ]
            [ p [] [ text description ]
            ]

        -- , div [ class "card-footer", class "content" ]
        -- [ p []
        -- [ text "tags"
        -- ]
        -- ]
        ]


viewPreviewWithoutImage : String -> Int -> String -> String -> Html Msg
viewPreviewWithoutImage title id description createdAt =
    div [ class "card" ]
        [ div [ class "card-head" ]
            [ p [ class "card-head-title", style "color" "black" ] [ text title ]
            ]
        , div [ class "content", style "color" "black" ] [ text description ]
        ]


imgUrl : Int -> String
imgUrl i =
    case i of
        1 ->
            foodImgUrl "cheese+cake"

        2 ->
            foodImgUrl "blue+berry+pie"

        25 ->
            pancakeImgUrl

        26 ->
            foodImgUrl "spaghetti"

        _ ->
            foodImgUrl "food"


foodImgUrl : String -> String
foodImgUrl query =
    "url(https://source.unsplash.com/640x480/?" ++ query ++ ")"


pancakeImgUrl : String
pancakeImgUrl =
    "url(https://assets.icanet.se/q_auto,f_auto/imagevaultfiles/id_185874/cf_259/pannkakstarta-med-choklad-och-nutella-724305-stor.jpg)"


viewError : Http.Error -> Html Msg
viewError error =
    case error of
        Http.BadUrl str ->
            text str

        Http.NetworkError ->
            text "NetworkError"

        Http.BadStatus status ->
            text ("BadStatus " ++ String.fromInt status)

        Http.BadBody str ->
            text ("BadBody " ++ str)

        Http.Timeout ->
            text "Timeout"



-- UPDATE


type Msg
    = LoadedRecipes (Result Http.Error (List (Recipe Preview)))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedRecipes (Ok recipes) ->
            ( { model | recipes = Loaded recipes }, Cmd.none )

        LoadedRecipes (Err error) ->
            ( { model | recipes = Failed error }, Cmd.none )



-- HTTP


url : String
url =
    Url.Builder.crossOrigin "http://localhost:3000"
        [ "recipes" ]
        [ Url.Builder.string "select" "id,title,description,created_at,updated_at" ]


getRecipes : Cmd Msg
getRecipes =
    Http.get
        { url = url
        , expect = Http.expectJson LoadedRecipes previewsDecoder
        }


previewsDecoder : Decoder (List (Recipe Preview))
previewsDecoder =
    list <| Recipe.previewDecoder



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
