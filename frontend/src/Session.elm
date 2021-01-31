module Session exposing
    ( Session
    , Window
    , addRecipe
    , build
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
    | SessionWithRecipe Nav.Key Element.Device (Maybe Dom.Viewport) (Recipe Full)


type alias Window =
    { width : Int, height : Int }


build : Nav.Key -> Window -> Session
build key window =
    Session key (classifyDevice window) Nothing


addRecipe : Recipe Full -> Session -> Session
addRecipe fullRecipe session =
    case session of
        Session key dev theViewport ->
            SessionWithRecipe key dev theViewport fullRecipe

        SessionWithRecipe key dev theViewport _ ->
            SessionWithRecipe key dev theViewport fullRecipe


updateWindowSize : Session -> Window -> Session
updateWindowSize session window =
    case session of
        Session key _ theViewport ->
            Session key (classifyDevice window) theViewport

        SessionWithRecipe key _ theViewport fullRecipe ->
            SessionWithRecipe key (classifyDevice window) theViewport fullRecipe


updateViewport : Session -> Dom.Viewport -> Session
updateViewport session theViewport =
    case session of
        Session key dev _ ->
            Session key dev (Just theViewport)

        SessionWithRecipe key dev _ fullRecipe ->
            SessionWithRecipe key dev (Just theViewport) fullRecipe


navKey : Session -> Nav.Key
navKey session =
    case session of
        Session key _ _ ->
            key

        SessionWithRecipe key _ _ _ ->
            key


recipe : Session -> Slug -> Maybe (Recipe Full)
recipe session slug =
    case session of
        Session _ _ _ ->
            Nothing

        SessionWithRecipe _ _ _ recipeFull ->
            matchingSlug slug recipeFull


device : Session -> Element.Device
device session =
    case session of
        Session _ dev _ ->
            dev

        SessionWithRecipe _ dev _ _ ->
            dev


viewport : Session -> Maybe Dom.Viewport
viewport session =
    case session of
        Session _ _ theViewport ->
            theViewport

        SessionWithRecipe _ _ theViewport _ ->
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
