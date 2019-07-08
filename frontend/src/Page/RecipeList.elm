module Page.RecipeList exposing (Model, Msg, Status, init, toSession, view)

import Browser exposing (Document)
import Html exposing (..)
import Http
import Recipe exposing (Preview, Recipe, previewDecoder)
import Session exposing (Session)
import Url
import Url.Builder



-- MODEL


type alias Model =
    { session : Session, recipes : List (Recipe Preview) }


type Status a
    = Loading
    | Loaded (List (Recipe Preview))


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , recipes = []
      }
    , getRecipes
    )


type Msg
    = LoadedRecipes (Result Http.Error (List (Recipe Preview)))


url : String
url =
    Url.Builder.crossOrigin "http://localhost:3000" [ "recipes" ] []


getRecipes : Cmd Msg
getRecipes =
    Http.get
        { url = url
        , expect = Http.expectJson LoadedRecipes Recipe.previewDecoder
        }


view : Model -> Document msg
view model =
    { title = "Recipe List", body = [ div [] [ text "recipe list" ] ] }



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
