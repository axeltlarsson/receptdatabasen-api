module Page.Recipe exposing (Model, Msg, init, toSession, update, view)

import Browser exposing (Document)
import Dict exposing (Dict)
import Html exposing (..)
import Http
import Json.Decode exposing (Decoder, dict, field, index, int, list, map2, map8, string)
import Session exposing (Session)
import Url exposing (Url)
import Url.Builder



--- MODEL


type alias Model =
    { session : Session, recipe : Status Recipe, error : Maybe Http.Error }


type Status a
    = Loading
    | Loaded a
    | Failed


type alias Recipe =
    { id : Int
    , title : String
    , description : String
    , instructions : String
    , tags : List String
    , quantity : Int
    , ingredients : Dict String (List String)
    , created_at : String
    }


init : Session -> Int -> ( Model, Cmd Msg )
init session slug =
    ( { recipe = Loading
      , session = session
      , error = Nothing
      }
    , getRecipe slug
    )



-- VIEW


view : Model -> Document msg
view model =
    case model.recipe of
        Loading ->
            { title = "Loading recipe"
            , body = [ text "Loading..." ]
            }

        Failed ->
            { title = "Failed to load"
            , body =
                [ text "Failed to load"
                , viewError model.error
                ]
            }

        Loaded recipe ->
            { title = "Individual recipe view"
            , body = [ viewRecipe recipe ]
            }


viewRecipe : Recipe -> Html msg
viewRecipe recipe =
    div []
        [ h1 [] [ text recipe.title ]
        , p [] [ text <| String.concat [ "Recipe id: ", String.fromInt recipe.id ] ]
        , p [] [ text recipe.description ]
        , p [] [ text <| String.concat [ "För ", String.fromInt recipe.quantity, " personer" ] ]
        , h2 [] [ text "Ingredienser" ]

        -- , text <| Debug.toString recipe.ingredients
        , viewIngredientsDict recipe.ingredients
        , h2 [] [ text "Instruktioner" ]
        , p [] [ text recipe.instructions ]
        , p [] [ text <| String.concat [ "Skapad: ", recipe.created_at ] ]
        ]


viewIngredientsDict : Dict String (List String) -> Html msg
viewIngredientsDict ingredients =
    div []
        (Dict.toList ingredients |> List.map viewGroupedIngredients)


viewGroupedIngredients : ( String, List String ) -> Html msg
viewGroupedIngredients ( groupKey, ingredients ) =
    div []
        [ h3 [] [ text groupKey ]
        , ul []
            (List.map viewIngredient ingredients)
        ]


viewIngredient : String -> Html msg
viewIngredient ingredient =
    li [] [ text ingredient ]


viewError : Maybe Http.Error -> Html msg
viewError error =
    case error of
        Just (Http.BadUrl str) ->
            text str

        Just Http.NetworkError ->
            text "NetworkError"

        Just (Http.BadStatus status) ->
            text ("BadStatus" ++ String.fromInt status)

        Just (Http.BadBody str) ->
            text ("BadBody" ++ str)

        Just Http.Timeout ->
            text "Timeout"

        Nothing ->
            text ""



-- UPDATE


type Msg
    = LoadedRecipe (Result Http.Error Recipe)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedRecipe (Ok recipe) ->
            ( { model | recipe = Loaded recipe }, Cmd.none )

        LoadedRecipe (Err error) ->
            ( { model | recipe = Failed, error = Just error }, Cmd.none )



-- HTTP


hardCodedUrl : String
hardCodedUrl =
    Url.Builder.crossOrigin "http://localhost:3000" [ "recipes" ] [ Url.Builder.string "id" "eq.4" ]


getRecipe : Int -> Cmd Msg
getRecipe slug =
    Http.get
        { url = hardCodedUrl
        , expect = Http.expectJson LoadedRecipe recipeDecoder
        }


recipeDecoder : Decoder Recipe
recipeDecoder =
    index 0 <|
        map8 Recipe
            (field "id" int)
            (field "title" string)
            (field "description" string)
            (field "instructions" string)
            (field "tags" (list string))
            (field "quantity" int)
            (field "ingredients" (dict (list string)))
            (field "created_at" string)



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
