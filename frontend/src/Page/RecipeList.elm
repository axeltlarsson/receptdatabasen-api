module Page.RecipeList exposing (Model, Msg, Status, init, toSession, update, view)

import Array exposing (Array)
import BlurHash
import Browser.Dom as Dom
import Element
    exposing
        ( Element
        , centerX
        , centerY
        , column
        , el
        , fill
        , height
        , image
        , link
        , padding
        , paragraph
        , rgba255
        , row
        , spacing
        , text
        , width
        , wrappedRow
        )
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Element.Lazy exposing (lazy, lazy2)
import Element.Region as Region
import FeatherIcons
import Html.Attributes
import Http
import Json.Decode as Decoder exposing (Decoder, list)
import Loading
import Page.Recipe.Markdown as Markdown
import Palette
import Recipe exposing (Preview, Recipe, previewDecoder)
import Recipe.Slug as Slug exposing (Slug)
import Route exposing (Route)
import Session exposing (Session)
import Task
import Url
import Url.Builder



-- MODEL


type alias Model =
    { session : Session, recipes : Status (Array (ImageLoadingStatus (Recipe Preview))), query : String }


type ImageLoadingStatus recipe
    = Blurred recipe
    | FullyLoaded recipe


type Status recipes
    = Loading
    | Loaded recipes
    | Failed Recipe.ServerError


init : Session -> Maybe String -> ( Model, Cmd Msg )
init session query =
    ( { session = session
      , recipes = Loading
      , query = Maybe.withDefault "" query
      }
    , case query of
        Nothing ->
            Recipe.fetchMany LoadedRecipes

        Just q ->
            search session q
    )



-- VIEW


view : Model -> { title : String, content : Element Msg }
view model =
    case model.recipes of
        Loading ->
            { title = "Recept"
            , content = Element.html Loading.animation
            }

        Failed err ->
            { title = "Kunde ej ladda in recept"
            , content =
                column [ Region.mainContent ]
                    [ Loading.error "Kunde ej ladda in recept" (Recipe.serverErrorToString err) ]
            }

        Loaded recipes ->
            { title = "Recept"
            , content =
                column [ Region.mainContent, spacing 20, width fill, padding 10 ]
                    [ lazy viewSearchBox model
                    , wrappedRow [ centerX, spacing 10 ]
                        (Array.indexedMap viewPreview recipes |> Array.toList)
                    ]
            }


viewSearchBox : Model -> Element Msg
viewSearchBox model =
    let
        placeholder =
            Input.placeholder []
                (row []
                    [ FeatherIcons.search |> FeatherIcons.toHtml [] |> Element.html
                    , text " Sök recept..."
                    ]
                )
    in
    Input.search [ Input.focusedOnLoad ]
        { onChange = SearchQueryEntered
        , text = model.query
        , placeholder = Just placeholder
        , label = Input.labelHidden "sök recept"
        }


imageWidths : { min : Int, max : Int }
imageWidths =
    let
        iPadWidth =
            768

        pagePadding =
            10

        max =
            768 - pagePadding * 2
    in
    -- iPad width: 768 - page padding x 2 = 748 => one recipe will fill the width on an iPad at most
    -- minimum: max - 10 for the spacing between recipes x 1/2 for good proportions
    { max = max
    , min = floor ((max - pagePadding) / 2)
    }


viewPreview : Int -> ImageLoadingStatus (Recipe Preview) -> Element Msg
viewPreview index recipeStatus =
    let
        recipe =
            case recipeStatus of
                Blurred r ->
                    r

                FullyLoaded r ->
                    r

        { title, description, id, createdAt, images } =
            Recipe.metadata recipe

        hash =
            "LKLWb2_M9}f8AgIVt7t7PqRoaiR-"

        imageUrl =
            case recipeStatus of
                Blurred r ->
                    List.head images
                        |> Maybe.map .blurHash
                        |> Maybe.map (Maybe.withDefault hash)
                        |> Maybe.map (BlurHash.toUri { width = 4, height = 3 } 0.9)

                FullyLoaded r ->
                    let
                        width =
                            -- *2 for Retina TODO: optimise with responsive/progressive images
                            String.fromInt <| imageWidths.max * 2
                    in
                    List.head images
                        |> Maybe.map .url
                        |> Maybe.map (\i -> "/images/sig/" ++ width ++ "/" ++ i)

        titleStr =
            Slug.toString title

        blurredUri =
            Just (BlurHash.toUri { width = 4, height = 3 } 0.9 hash)
    in
    lazy2 column
        [ width (fill |> Element.maximum imageWidths.max |> Element.minimum imageWidths.min)
        , height <| Element.px 400
        , Palette.cardShadow1
        , Palette.cardShadow2
        , Border.rounded 2
        ]
        [ Element.link [ height fill, width fill, Events.onMouseEnter (UnBlur index) ]
            { url = Route.toString (Route.Recipe title)
            , label =
                el [ height fill, width fill ]
                    (viewHeader id titleStr imageUrl description)
            }
        ]


viewHeader : Int -> String -> Maybe String -> Maybe String -> Element Msg
viewHeader id title imageUrl description =
    let
        dataAttribute uri =
            Element.htmlAttribute (Html.Attributes.attribute "data-src" uri)

        imgAttr =
            Element.htmlAttribute (Html.Attributes.class "fit-img")
    in
    column [ width fill, height fill, Border.rounded 2 ]
        [ column
            [ width fill
            , height fill
            ]
            [ el
                [ height fill
                , width fill
                , Element.clip
                , Element.inFront
                    (el
                        [ Element.behindContent <|
                            el
                                [ width fill
                                , height fill
                                , floorFade
                                ]
                                Element.none
                        , width fill
                        , height fill
                        ]
                        (column [ Element.alignBottom ]
                            [ paragraph
                                [ Font.medium
                                , Font.color Palette.white
                                , Palette.textShadow
                                , Font.size Palette.medium
                                , padding 20
                                ]
                                [ text title ]
                            ]
                        )
                    )
                ]
                (imageUrl
                    |> Maybe.map
                        (\url ->
                            image [ Border.rounded 2, width fill, height fill, imgAttr, Element.clip ]
                                { src = url, description = "" }
                        )
                    |> Maybe.withDefault Element.none
                )
            , viewDescription description
            ]
        ]


debug =
    Element.explain Debug.todo


floorFade : Element.Attribute msg
floorFade =
    Background.gradient
        { angle = pi -- down
        , steps =
            [ rgba255 0 0 0 0
            , rgba255 0 0 0 0.2
            ]
        }


takeWordsUntilCharLimit : Int -> List String -> List String
takeWordsUntilCharLimit limit words =
    let
        f : String -> List String -> List String
        f w ws =
            if (String.join " " >> String.length) (List.append ws [ w ]) < limit then
                List.append ws [ w ]

            else
                ws
    in
    List.foldl f [] words


shorten : Int -> String -> String
shorten limit str =
    let
        append x y =
            -- String.append is weird, so need to switch args
            y ++ x
    in
    if String.length str <= limit then
        str

    else
        takeWordsUntilCharLimit limit (str |> String.trim |> String.words)
            |> String.join " "
            |> append "..."


viewDescription : Maybe String -> Element Msg
viewDescription description =
    Maybe.withDefault Element.none <|
        Maybe.map
            (shorten 147
                >> text
                >> el
                    [ Font.hairline
                    , Font.color Palette.nearBlack
                    , Element.htmlAttribute <| Html.Attributes.style "overflow-wrap" "anywhere"
                    ]
                >> List.singleton
                >> paragraph [ padding 20, Element.alignBottom ]
            )
            description



-- UPDATE


type Msg
    = LoadedRecipes (Result Recipe.ServerError (List (Recipe Preview)))
    | SearchQueryEntered String
    | SetViewport
    | UnBlur Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedRecipes (Ok recipes) ->
            let
                setViewportFromSession session =
                    Session.viewport session
                        |> Maybe.map
                            (\{ viewport } ->
                                [ Task.perform (\_ -> SetViewport) (Dom.setViewport viewport.x viewport.y) ]
                            )
                        |> Maybe.withDefault []
                        |> Cmd.batch
            in
            ( { model | recipes = Loaded (List.map Blurred recipes |> Array.fromList) }, setViewportFromSession model.session )

        LoadedRecipes (Err error) ->
            ( { model | recipes = Failed error }, Cmd.none )

        SearchQueryEntered "" ->
            ( { model | query = "" }, Recipe.fetchMany LoadedRecipes )

        SearchQueryEntered query ->
            ( { model | query = query }, search model.session query )

        SetViewport ->
            ( model, Cmd.none )

        UnBlur index ->
            ( { model | recipes = unBlur index model.recipes }, Cmd.none )


unBlur : Int -> Status (Array (ImageLoadingStatus (Recipe Preview))) -> Status (Array (ImageLoadingStatus (Recipe Preview)))
unBlur index recipeStatuses =
    case recipeStatuses of
        Loaded recipes ->
            let
                recipe =
                    Array.get index recipes

                updated =
                    recipe
                        |> Maybe.map
                            (\status ->
                                case status of
                                    Blurred r ->
                                        FullyLoaded r

                                    FullyLoaded r ->
                                        FullyLoaded r
                            )
                        |> Maybe.map
                            (\x ->
                                Array.set index x recipes
                            )
            in
            Loaded (Maybe.withDefault recipes updated)

        _ ->
            recipeStatuses


search : Session -> String -> Cmd Msg
search session query =
    Cmd.batch
        [ Route.RecipeList (Just query)
            |> Route.replaceUrl (Session.navKey session)
        , Recipe.search LoadedRecipes query
        ]



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
