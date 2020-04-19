module Session exposing (Session, Window, addRecipe, build, buildWithRecipe, device, navKey, recipe, updateWindowSize)

import Browser.Navigation as Nav
import Element exposing (classifyDevice)
import Recipe exposing (Full, Recipe)
import Recipe.Slug as Slug exposing (Slug)
import Url


type Session
    = Session Nav.Key Element.Device
    | SessionWithRecipe (Recipe Full) Nav.Key Element.Device


type alias Window =
    { width : Int, height : Int }


build : Nav.Key -> Window -> Session
build key window =
    Session key (classifyDevice window)


buildWithRecipe : Nav.Key -> Window -> Recipe Full -> Session
buildWithRecipe key window fullRecipe =
    SessionWithRecipe fullRecipe key (classifyDevice window)


addRecipe : Recipe Full -> Session -> Session
addRecipe fullRecipe session =
    case session of
        Session key dev ->
            SessionWithRecipe fullRecipe key dev

        SessionWithRecipe oldRecipe key dev ->
            SessionWithRecipe fullRecipe key dev


updateWindowSize : Session -> Window -> Session
updateWindowSize session window =
    case session of
        Session key dev ->
            Session key (classifyDevice window)

        SessionWithRecipe fullRecipe key dev ->
            SessionWithRecipe fullRecipe key (classifyDevice window)


navKey : Session -> Nav.Key
navKey session =
    case session of
        Session key _ ->
            key

        SessionWithRecipe _ key _ ->
            key


recipe : Session -> Slug -> Maybe (Recipe Full)
recipe session slug =
    case session of
        Session _ _ ->
            Nothing

        SessionWithRecipe recipeFull _ _ ->
            matchingSlug slug recipeFull


device : Session -> Element.Device
device session =
    case session of
        Session key dev ->
            dev

        SessionWithRecipe _ _ dev ->
            dev



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
