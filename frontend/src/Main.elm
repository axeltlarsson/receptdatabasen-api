module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Page.Recipe as Recipe
import Page.Recipe.Editor as Editor
import Page.RecipeList as RecipeList
import Route exposing (Route)
import Session exposing (Session)
import Url



-- MODEL


type Model
    = Recipe Recipe.Model
    | RecipeList RecipeList.Model
    | Redirect Session
    | NotFound Session
    | Editor (Maybe Int) Editor.Model


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    changeRouteTo (Route.fromUrl url)
        (Redirect (Session.fromKey key))



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        viewPage { title, body } toMsg =
            { title = title
            , body = List.map (Html.map toMsg) body
            }
    in
    case model of
        Redirect _ ->
            { title = "Redirect", body = [ text "not found" ] }

        NotFound _ ->
            { title = "Not Found"
            , body =
                [ text "Not found"
                , viewLinks
                ]
            }

        Recipe recipe ->
            viewPage (Recipe.view recipe) GotRecipeMsg

        RecipeList recipes ->
            viewPage (RecipeList.view recipes) GotRecipeListMsg

        Editor _ editor ->
            viewPage (Editor.view editor) GotEditorMsg


viewLinks : Html msg
viewLinks =
    ul []
        [ viewLink "/recipes"
        , viewLink "/recipes/1"
        , viewLink "/editor"
        ]


viewLink : String -> Html msg
viewLink path =
    li [] [ a [ href path ] [ text path ] ]



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotRecipeMsg Recipe.Msg
    | GotRecipeListMsg RecipeList.Msg
    | GotEditorMsg Editor.Msg


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
                |> updateWith Recipe GotRecipeMsg model

        Just Route.RecipeList ->
            RecipeList.init session
                |> updateWith RecipeList GotRecipeListMsg model

        Just Route.NewRecipe ->
            Editor.initNew session
                |> updateWith (Editor Nothing) GotEditorMsg model


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
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
                |> updateWith Recipe GotRecipeMsg model

        ( GotRecipeListMsg subMsg, RecipeList recipes ) ->
            RecipeList.update subMsg recipes
                |> updateWith RecipeList GotRecipeListMsg model

        ( GotEditorMsg subMsg, Editor Nothing editor ) ->
            Editor.update subMsg editor
                |> updateWith (Editor Nothing) GotEditorMsg model

        ( _, _ ) ->
            -- Disregard messages that arrived for the wrong page
            ( model, Cmd.none )


updateWith : (subModel -> Model) -> (subMsg -> Msg) -> Model -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg model ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }
