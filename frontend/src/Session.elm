module Session exposing (Session, addRecipe, build, buildWithRecipe, navKey, recipe)

import Browser.Navigation as Nav
import Recipe exposing (Full, Recipe)
import Recipe.Slug as Slug exposing (Slug)
import Url


type Session
    = Session Nav.Key Window
    | SessionWithRecipe (Recipe Full) Nav.Key Window


type Window
    = Window Width Height


type alias Width =
    Int


type alias Height =
    Int


navKey : Session -> Nav.Key
navKey session =
    case session of
        Session key _ ->
            key

        SessionWithRecipe _ key _ ->
            key


build : Nav.Key -> Width -> Height -> Session
build key width height =
    Session key (Window width height)


buildWithRecipe : Nav.Key -> Width -> Height -> Recipe Full -> Session
buildWithRecipe key width height fullRecipe =
    SessionWithRecipe fullRecipe key (Window width height)


addRecipe : Recipe Full -> Session -> Session
addRecipe fullRecipe session =
    case session of
        Session key window ->
            SessionWithRecipe fullRecipe key window

        SessionWithRecipe oldRecipe key window ->
            SessionWithRecipe fullRecipe key window


recipe : Session -> Slug -> Maybe (Recipe Full)
recipe session slug =
    case session of
        Session _ _ ->
            Nothing

        SessionWithRecipe recipeFull _ _ ->
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
