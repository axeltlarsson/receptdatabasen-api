module Main exposing (main)

import Browser exposing (Document)
import Browser.Events
import Browser.Navigation as Nav
import Html
import Json.Decode as D
import Json.Encode as E
import Page exposing (Page)
import Page.Blank
import Page.NotFound
import Page.Recipe as Recipe
import Page.Recipe.Editor as Editor
import Page.RecipeList as RecipeList
import Recipe.Slug as Slug exposing (Slug)
import Route exposing (Route)
import Session exposing (Session)
import Url



-- MODEL


type Model
    = Recipe Recipe.Model
    | RecipeList RecipeList.Model
    | Redirect Session
    | NotFound Session
    | Editor (Maybe Slug) Editor.Model


init : E.Value -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        decodedFlags =
            case D.decodeValue flagsDecoder flags of
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


flagsDecoder : D.Decoder Flags
flagsDecoder =
    D.map2 Flags
        (D.field "width" D.int)
        (D.field "height" D.int)



-- VIEW


view : Model -> Document Msg
view model =
    let
        viewPage page toMsg config =
            let
                { title, body } =
                    Page.view page config
            in
            { title = title, body = List.map (Html.map toMsg) body }
    in
    case model of
        Redirect _ ->
            Page.view Page.Other Page.Blank.view

        NotFound _ ->
            Page.view Page.Other Page.NotFound.view

        Recipe recipe ->
            viewPage Page.Recipe GotRecipeMsg (Recipe.view recipe)

        RecipeList recipes ->
            viewPage Page.RecipeList GotRecipeListMsg (RecipeList.view recipes)

        Editor _ editor ->
            viewPage Page.Editor GotEditorMsg (Editor.view editor)



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotRecipeMsg Recipe.Msg
    | GotRecipeListMsg RecipeList.Msg
    | GotEditorMsg Editor.Msg
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

        Just Route.RecipeList ->
            RecipeList.init session
                |> updateWith RecipeList GotRecipeListMsg

        Just Route.NewRecipe ->
            Editor.initNew session
                |> updateWith (Editor Nothing) GotEditorMsg

        Just (Route.EditRecipe slug) ->
            Editor.initEdit session slug
                |> updateWith (Editor (Just slug)) GotEditorMsg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        updateSession window =
            Session.updateWindowSize (toSession model) window
    in
    case ( msg, model ) of
        ( LinkClicked urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    ( model
                    , Nav.pushUrl (Session.navKey (toSession model)) (Url.toString url)
                    )

                Browser.External href ->
                    ( model, Nav.load href )

        ( UrlChanged url, _ ) ->
            changeRouteTo (Route.fromUrl url) model

        ( GotRecipeMsg subMsg, Recipe recipe ) ->
            Recipe.update subMsg recipe
                |> updateWith Recipe GotRecipeMsg

        ( GotRecipeListMsg subMsg, RecipeList recipes ) ->
            RecipeList.update subMsg recipes
                |> updateWith RecipeList GotRecipeListMsg

        ( GotEditorMsg subMsg, Editor slug editor ) ->
            Editor.update subMsg editor
                |> updateWith (Editor slug) GotEditorMsg

        ( GotWindowResize window, page ) ->
            case page of
                Recipe recipe ->
                    ( Recipe { recipe | session = updateSession window }, Cmd.none )

                RecipeList recipes ->
                    ( RecipeList { recipes | session = updateSession window }, Cmd.none )

                Editor slug editor ->
                    ( Editor slug { editor | session = updateSession window }, Cmd.none )

                Redirect session ->
                    ( Redirect (updateSession window), Cmd.none )

                NotFound session ->
                    ( NotFound (updateSession window), Cmd.none )

        ( _, _ ) ->
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
subscriptions _ =
    Browser.Events.onResize (\w h -> GotWindowResize { width = w, height = h })



-- MAIN


main : Program E.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }
