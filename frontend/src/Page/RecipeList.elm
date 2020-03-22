module Page.RecipeList exposing (Model, Msg, Status, init, toSession, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput)
import Http
import Json.Decode as Decoder exposing (Decoder, list)
import Loading
import Recipe exposing (Preview, Recipe, previewDecoder)
import Recipe.Slug as Slug exposing (Slug)
import Route exposing (Route)
import Session exposing (Session)
import Url
import Url.Builder



-- MODEL


type alias Model =
    { session : Session, recipes : Status (List (Recipe Preview)), query : String }


type Status recipes
    = Loading
    | Loaded recipes
    | Failed Recipe.ServerError


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , recipes = Loading
      , query = ""
      }
    , Recipe.fetchMany LoadedRecipes
    )



-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    case model.recipes of
        Loading ->
            { title = "Recipes"
            , content = Loading.animation
            }

        Failed err ->
            { title = "Failed to load"
            , content =
                main_ [ class "content" ]
                    [ Loading.error "Kunde ej ladda in recept" (Recipe.serverErrorToString err) ]
            }

        Loaded recipes ->
            { title = "Recipes"
            , content =
                div []
                    [ viewSearchBox model, div [ class "row" ] (List.map viewPreview recipes) ]
            }


viewSearchBox : Model -> Html Msg
viewSearchBox model =
    div [ class "row" ]
        [ div [ class "form-group" ]
            [ input [ type_ "search", class "form-group-input", onInput SearchQueryEntered, value model.query ] []
            ]
        ]


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


viewPreviewWithImage : String -> Int -> Maybe String -> String -> Html Msg
viewPreviewWithImage title id description createdAt =
    div [ class "card u-flex u-flex-column h-90" ]
        [ div [ class "card-container" ]
            [ div [ class "card-image", style "background-image" (imgUrl id) ] []
            , div [ class "title-container" ]
                [ p [ class "title" ] [ text title ]

                -- , span [ class "subtitle" ] [ text "by me" ]
                ]
            ]
        , div [ class "content", style "color" "black" ]
            [ p [] [ text (shortDescription <| Maybe.withDefault "" description) ]
            ]

        -- , div [ class "card-footer", class "content" ]
        -- [ p []
        -- [ text "tags"
        -- ]
        -- ]
        ]


shortDescription : String -> String
shortDescription description =
    if String.length description <= 147 then
        description

    else
        String.left 150 description ++ "..."


viewPreviewWithoutImage : String -> Int -> Maybe String -> String -> Html Msg
viewPreviewWithoutImage title id description createdAt =
    div [ class "card" ]
        [ div [ class "card-head" ]
            [ p [ class "card-head-title", style "color" "black" ] [ text title ]
            ]
        , div [ class "content", style "color" "black" ] [ text <| Maybe.withDefault "" description ]
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



-- UPDATE


type Msg
    = LoadedRecipes (Result Recipe.ServerError (List (Recipe Preview)))
    | SearchQueryEntered String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedRecipes (Ok recipes) ->
            ( { model | recipes = Loaded recipes }, Cmd.none )

        LoadedRecipes (Err error) ->
            ( { model | recipes = Failed error }, Cmd.none )

        SearchQueryEntered "" ->
            ( { model | query = "" }, Recipe.fetchMany LoadedRecipes )

        SearchQueryEntered query ->
            ( { model | query = query }, Recipe.search LoadedRecipes query )



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
