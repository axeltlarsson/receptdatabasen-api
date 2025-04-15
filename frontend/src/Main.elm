module Main exposing (main)

import Browser exposing (Document)
import Browser.Dom
import Browser.Events
import Browser.Navigation as Nav
import Html
import Json.Decode as Decode
import Json.Encode as Encode
import Page
import Page.Blank
import Page.Login as Login
import Page.MyProfile as MyProfile
import Page.NotFound
import Page.Recipe as Recipe
import Page.Recipe.Editor as Editor
import Page.RecipeList as RecipeList
import Recipe.Slug exposing (Slug)
import Route exposing (Route)
import Session exposing (Session)
import Task
import Url



-- MODEL


type Model
    = Recipe Recipe.Model
    | RecipeList RecipeList.Model
    | Redirect Session
    | NotFound Session
    | Editor (Maybe Slug) Editor.Model
    | Login (Maybe Slug) Login.Model
    | MyProfile MyProfile.Model


init : Encode.Value -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        decodedFlags =
            case Decode.decodeValue flagsDecoder flags of
                Ok window ->
                    window

                Err _ ->
                    { width = 0, height = 0 }

        session =
            Session.build key decodedFlags
    in
    changeRouteTo (Route.fromUrl url)
        (Redirect session)


type alias Flags =
    { width : Int, height : Int }


flagsDecoder : Decode.Decoder Flags
flagsDecoder =
    Decode.map2 Flags
        (Decode.field "width" Decode.int)
        (Decode.field "height" Decode.int)



-- VIEW


view : Model -> Document Msg
view model =
    let
        viewPage page toMsg config =
            let
                { title, body } =
                    Page.view page (toSession model) config
            in
            { title = title, body = List.map (Html.map toMsg) body }

        viewPageWithoutHeader page toMsg config =
            let
                { title, body } =
                    Page.viewWithoutHeader page config
            in
            { title = title, body = List.map (Html.map toMsg) body }
    in
    case model of
        Redirect x ->
            Page.view Page.Other (toSession <| Redirect x) Page.Blank.view

        NotFound x ->
            Page.view Page.Other (toSession <| NotFound x) Page.NotFound.view

        Recipe recipe ->
            viewPage Page.Recipe GotRecipeMsg (Recipe.view recipe)

        RecipeList recipes ->
            viewPage Page.RecipeList GotRecipeListMsg (RecipeList.view recipes)

        Editor _ editor ->
            viewPage Page.Editor GotEditorMsg (Editor.view editor)

        Login _ login ->
            viewPageWithoutHeader Page.Login GotLoginMsg (Login.view login)

        MyProfile profile ->
            viewPage Page.MyProfile GotMyProfileMsg (MyProfile.view profile)



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotViewport Url.Url Browser.Dom.Viewport
    | GotRecipeMsg Recipe.Msg
    | GotRecipeListMsg RecipeList.Msg
    | GotEditorMsg Editor.Msg
    | GotLoginMsg Login.Msg
    | GotMyProfileMsg MyProfile.Msg
    | GotWindowResize Session.Window


toSession : Model -> Session
toSession page =
    case page of
        Redirect session ->
            session

        NotFound session ->
            session

        Recipe recipe ->
            Recipe.toSession recipe

        RecipeList recipes ->
            RecipeList.toSession recipes

        Editor _ editor ->
            Editor.toSession editor

        Login _ login ->
            Login.toSession login

        MyProfile profile ->
            MyProfile.toSession profile


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
    let
        session =
            toSession model
    in
    case maybeRoute of
        Nothing ->
            ( NotFound session, Cmd.none )

        Just (Route.Recipe slug) ->
            Recipe.init session slug
                |> updateWith Recipe GotRecipeMsg

        Just (Route.RecipeList query) ->
            case model of
                -- Avoid infinite recursion if URL change is in search query for RecipeList
                RecipeList _ ->
                    ( model, Cmd.none )

                _ ->
                    RecipeList.init session query |> updateWith RecipeList GotRecipeListMsg

        Just Route.NewRecipe ->
            Editor.initNew session
                |> updateWith (Editor Nothing) GotEditorMsg

        Just (Route.EditRecipe slug) ->
            Editor.initEdit session slug
                |> updateWith (Editor (Just slug)) GotEditorMsg

        Just (Route.Login maybeSlug) ->
            Login.init session maybeSlug |> updateWith (Login maybeSlug) GotLoginMsg

        Just Route.MyProfile ->
            MyProfile.init session |> updateWith MyProfile GotMyProfileMsg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        updateSession page newSession =
            case page of
                Recipe recipe ->
                    Recipe { recipe | session = newSession }

                RecipeList recipes ->
                    RecipeList { recipes | session = newSession }

                Editor slug editor ->
                    Editor slug { editor | session = newSession }

                Redirect _ ->
                    Redirect newSession

                NotFound _ ->
                    NotFound newSession

                Login maybeSlug login ->
                    Login maybeSlug { login | session = newSession }

                MyProfile profile ->
                    MyProfile { profile | session = newSession }
    in
    case ( msg, model ) of
        ( LinkClicked urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Task.perform (GotViewport url) Browser.Dom.getViewport )

                Browser.External href ->
                    ( model, Nav.load href )

        ( UrlChanged url, _ ) ->
            changeRouteTo (Route.fromUrl url) model

        ( GotViewport url viewport, page ) ->
            let
                newSession =
                    Session.updateViewport (toSession model) viewport
            in
            ( updateSession page newSession
            , Nav.pushUrl (Session.navKey (toSession model)) (Url.toString url)
            )

        ( GotRecipeMsg subMsg, Recipe recipe ) ->
            Recipe.update subMsg recipe
                |> updateWith Recipe GotRecipeMsg

        ( GotRecipeListMsg subMsg, RecipeList recipes ) ->
            RecipeList.update subMsg recipes
                |> updateWith RecipeList GotRecipeListMsg

        ( GotEditorMsg subMsg, Editor slug editor ) ->
            Editor.update subMsg editor
                |> updateWith (Editor slug) GotEditorMsg

        ( GotLoginMsg subMsg, Login maybeSlug login ) ->
            Login.update subMsg login
                |> updateWith (Login maybeSlug) GotLoginMsg

        ( GotMyProfileMsg subMsg, MyProfile profile ) ->
            MyProfile.update subMsg profile
                |> updateWith MyProfile GotMyProfileMsg

        ( GotWindowResize window, page ) ->
            let
                newSession =
                    Session.updateWindowSize (toSession model) window
            in
            ( updateSession page newSession, Cmd.none )

        _ ->
            -- Disregard messages that arrived for the wrong page
            ( model, Cmd.none )


updateWith :
    (subModel -> Model)
    -> (subMsg -> Msg)
    -> ( subModel, Cmd subMsg )
    -> ( Model, Cmd Msg )
updateWith toModel toMsg ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        modelSubs =
            case model of
                NotFound _ ->
                    Sub.none

                Recipe _ ->
                    Sub.none

                RecipeList _ ->
                    Sub.none

                Redirect _ ->
                    Sub.none

                Editor _ editor ->
                    Sub.map GotEditorMsg (Editor.subscriptions editor)

                Login _ login ->
                    Sub.map GotLoginMsg (Login.subscriptions login)

                MyProfile profile ->
                    Sub.map GotMyProfileMsg (MyProfile.subscriptions profile)

        windowResizeSub =
            Browser.Events.onResize (\w h -> GotWindowResize { width = w, height = h })
    in
    Sub.batch
        [ windowResizeSub
        , modelSubs
        ]



-- MAIN


main : Program Encode.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }
