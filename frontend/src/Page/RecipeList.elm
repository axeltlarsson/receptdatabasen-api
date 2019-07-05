module Page.RecipeList exposing (Model, Status(..))

import Browser exposing (Document)
import Recipe exposing (Preview, Recipe)
import Session exposing (Session)



-- MODEL


type alias Model =
    { session : Session, recipes : List (Recipe Preview) }


type Status a
    = Loading
    | Loaded (List (Recipe Preview))
