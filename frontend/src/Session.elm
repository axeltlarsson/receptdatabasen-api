module Session exposing (Session(..), fromKey, navKey, recipe)

import Browser.Navigation as Nav
import Recipe exposing (Full, Recipe)
import Recipe.Slug as Slug exposing (Slug)
import Url


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


recipe : Session -> Slug -> Maybe (Recipe Full)
recipe session slug =
    case session of
        Session _ ->
            Nothing

        SessionWithRecipe recipeFull _ ->
            matchingSlug slug recipeFull



-- Helpers


matchingSlug : Slug -> Recipe Full -> Maybe (Recipe Full)
matchingSlug slug recipe_ =
    let
        slugDecoded =
            Maybe.withDefault "" <| Url.percentDecode <| Slug.toString slug
    in
    if Slug.toString (Recipe.slug recipe_) == slugDecoded then
        Just
            recipe_

    else
        Nothing
