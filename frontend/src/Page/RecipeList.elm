module Page.RecipeList exposing (Model, Msg, Status, init, toSession, update, view)

import Element
    exposing
        ( Element
        , centerX
        , centerY
        , column
        , el
        , fill
        , height
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
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import FeatherIcons
import Http
import Json.Decode as Decoder exposing (Decoder, list)
import Loading
import Palette
import Recipe exposing (Preview, Recipe, previewDecoder)
import Recipe.Slug as Slug exposing (Slug)
import Route exposing (Route)
import Session exposing (Session)
import Url
import Url.Builder



-- MODEL


type alias Model =
    { session : Session, recipes : Status (List (Recipe Preview)), query : String }


type Status recipes
    = Loading
    | Loaded recipes
    | Failed Recipe.ServerError


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , recipes = Loading
      , query = ""
      }
    , Recipe.fetchMany LoadedRecipes
    )



-- VIEW


view : Model -> { title : String, content : Element Msg }
view model =
    case model.recipes of
        Loading ->
            { title = "Recipes"
            , content = Element.html Loading.animation
            }

        Failed err ->
            { title = "Failed to load"
            , content =
                column [ Region.mainContent ]
                    [ Loading.error "Kunde ej ladda in recept" (Recipe.serverErrorToString err) ]
            }

        Loaded recipes ->
            { title = "Recipes"
            , content =
                column [ Region.mainContent, spacing 20, width fill, padding 10 ]
                    [ viewSearchBox model
                    , wrappedRow [ centerX, spacing 10 ]
                        (List.map viewPreview recipes)
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


debug : Element.Attribute msg
debug =
    Element.explain Debug.todo


viewPreview : Recipe Preview -> Element Msg
viewPreview recipe =
    let
        { title, description, id, createdAt } =
            Recipe.metadata recipe

        titleStr =
            Slug.toString title
    in
    column
        -- iPad width: 768 - page padding x 2 = 748 => one recipe will fill the width on an iPad at most
        -- minimum: max - 10 for the spacing between recipes x 1/2 for good proportions
        [ width (fill |> Element.maximum 748 |> Element.minimum 369)
        , height <| Element.px 400
        , Palette.cardShadow1
        , Palette.cardShadow2
        , Border.rounded 2
        ]
        [ Element.link [ height fill, width fill ]
            { url = Route.toString (Route.Recipe title)
            , label =
                column [ height fill, width fill ]
                    [ viewHeader id titleStr
                    , viewDescription description
                    ]
            }
        ]


viewHeader : Int -> String -> Element Msg
viewHeader id title =
    column [ width fill, height fill, Border.rounded 2 ]
        [ Element.el
            [ width fill
            , height fill
            , Border.rounded 2
            , Background.image <| imgUrl id
            ]
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


viewDescription : Maybe String -> Element Msg
viewDescription description =
    let
        append x y =
            -- String.append is weird, so need to switch args
            y ++ x

        shorten descr =
            if String.length descr <= 147 then
                descr

            else
                takeWordsUntilCharLimit 147 (descr |> String.trim |> String.words)
                    |> String.join " "
                    |> append "..."
    in
    Maybe.withDefault Element.none <|
        Maybe.map
            (shorten
                >> text
                >> el [ Font.hairline, Font.color Palette.nearBlack ]
                >> List.singleton
                >> paragraph [ padding 20, width fill, Element.alignBottom ]
            )
            description


imgUrl : Int -> String
imgUrl i =
    case i of
        1 ->
            foodImgUrl "cheese+cake"

        2 ->
            foodImgUrl "pancake"

        3 ->
            foodImgUrl "omelette"

        4 ->
            iceCoffeeUrl

        5 ->
            lemonadeUrl

        _ ->
            foodImgUrl "food"


foodImgUrl : String -> String
foodImgUrl query =
    "https://source.unsplash.com/640x480/?" ++ query


pancakeImgUrl : String
pancakeImgUrl =
    "https://assets.icanet.se/q_auto,f_auto/imagevaultfiles/id_185874/cf_259/pannkakstarta-med-choklad-och-nutella-724305-stor.jpg"


lemonadeUrl : String
lemonadeUrl =
    "https://assets.icanet.se/q_auto,f_auto/imagevaultfiles/id_214425/cf_259/rabarberlemonad-721978.jpg"


iceCoffeeUrl : String
iceCoffeeUrl =
    "https://assets.icanet.se/q_auto,f_auto/imagevaultfiles/id_214221/cf_259/iskaffe-med-kondenserad-mjolk-och-choklad-726741.jpg"



-- UPDATE


type Msg
    = LoadedRecipes (Result Recipe.ServerError (List (Recipe Preview)))
    | SearchQueryEntered String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadedRecipes (Ok recipes) ->
            ( { model | recipes = Loaded recipes }, Cmd.none )

        LoadedRecipes (Err error) ->
            ( { model | recipes = Failed error }, Cmd.none )

        SearchQueryEntered "" ->
            ( { model | query = "" }, Recipe.fetchMany LoadedRecipes )

        SearchQueryEntered query ->
            ( { model | query = query }, Recipe.search LoadedRecipes query )



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
