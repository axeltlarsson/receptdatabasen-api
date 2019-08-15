module Session exposing (Session(..), fromKey, navKey, recipe)

import Browser.Navigation as Nav
import Recipe exposing (Full, Recipe)


type Session
    = Session Nav.Key
    | SessionWithRecipe (Recipe Full) Nav.Key


navKey : Session -> Nav.Key
navKey session =
    case session of
        Session key ->
            key

        SessionWithRecipe _ key ->
            key


fromKey : Nav.Key -> Session
fromKey key =
    Session key


recipe : Session -> Maybe (Recipe Full)
recipe session =
    case session of
        Session _ ->
            Nothing

        SessionWithRecipe recipeFull _ ->
            Just recipeFull
