module Session exposing
    ( Session
    , Window
    , addRecipe
    , build
    , buildWithRecipe
    , device
    , navKey
    , recipe
    , updateViewport
    , updateWindowSize
    , viewport
    )

import Browser.Dom as Dom
import Browser.Navigation as Nav
import Element exposing (classifyDevice)
import Recipe exposing (Full, Recipe)
import Recipe.Slug as Slug exposing (Slug)
import Url


type Session
    = Session Nav.Key Element.Device (Maybe Dom.Viewport)
    | SessionWithRecipe (Recipe Full) Nav.Key Element.Device (Maybe Dom.Viewport)


type alias Window =
    { width : Int, height : Int }


build : Nav.Key -> Window -> Session
build key window =
    Session key (classifyDevice window) Nothing


buildWithRecipe : Nav.Key -> Window -> Recipe Full -> Session
buildWithRecipe key window fullRecipe =
    SessionWithRecipe fullRecipe key (classifyDevice window) Nothing


addRecipe : Recipe Full -> Session -> Session
addRecipe fullRecipe session =
    case session of
        Session key dev theViewport ->
            SessionWithRecipe fullRecipe key dev theViewport

        SessionWithRecipe oldRecipe key dev theViewport ->
            SessionWithRecipe fullRecipe key dev theViewport


updateWindowSize : Session -> Window -> Session
updateWindowSize session window =
    case session of
        Session key dev theViewport ->
            Session key (classifyDevice window) theViewport

        SessionWithRecipe fullRecipe key dev theViewport ->
            SessionWithRecipe fullRecipe key (classifyDevice window) theViewport


updateViewport : Session -> Dom.Viewport -> Session
updateViewport session theViewport =
    case session of
        Session key dev oldViewport ->
            Session key dev (Just theViewport)

        SessionWithRecipe fullRecipe key dev oldViewport ->
            SessionWithRecipe fullRecipe key dev (Just theViewport)


navKey : Session -> Nav.Key
navKey session =
    case session of
        Session key _ _ ->
            key

        SessionWithRecipe _ key _ _ ->
            key


recipe : Session -> Slug -> Maybe (Recipe Full)
recipe session slug =
    case session of
        Session _ _ _ ->
            Nothing

        SessionWithRecipe recipeFull _ _ _ ->
            matchingSlug slug recipeFull


device : Session -> Element.Device
device session =
    case session of
        Session _ dev _ ->
            dev

        SessionWithRecipe _ _ dev _ ->
            dev


viewport : Session -> Maybe Dom.Viewport
viewport session =
    case session of
        Session _ _ theViewport ->
            theViewport

        SessionWithRecipe _ _ _ theViewport ->
            theViewport



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
