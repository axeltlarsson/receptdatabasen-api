module Page.RecipeList exposing (Model, Msg, Status, init, toSession, update, view)

import Element exposing (Element, column, el, link, padding, row, spacing, text)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Http
import Json.Decode as Decoder exposing (Decoder, list)
import Loading
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
                column [ Region.mainContent ]
                    [ viewSearchBox model
                    , column []
                        (List.map viewPreview recipes)
                    ]
            }


viewSearchBox : Model -> Element Msg
viewSearchBox model =
    Input.search [ Input.focusedOnLoad ]
        { onChange = SearchQueryEntered
        , text = model.query
        , placeholder = Just (Input.placeholder [] (text "Sök recept..."))
        , label = Input.labelHidden "sök recept"
        }


viewPreview : Recipe Preview -> Element Msg
viewPreview recipe =
    let
        { title, description, id, createdAt } =
            Recipe.metadata recipe

        titleStr =
            Slug.toString title
    in
    row []
        [ Element.link []
            { url = Route.toString (Route.Recipe title)
            , label = el [] (text titleStr)
            }
        ]



{--
  - viewPreviewWithImage : String -> Int -> Maybe String -> String -> Html Msg
  - viewPreviewWithImage title id description createdAt =
  -     div [ class "card u-flex u-flex-column h-90" ]
  -         [ div [ class "card-container" ]
  -             [ div [ class "card-image", style "background-image" (imgUrl id) ] []
  -             , div [ class "title-container" ]
  -                 [ p [ class "title" ] [ text title ]
  - 
  -                 -- , span [ class "subtitle" ] [ text "by me" ]
  -                 ]
  -             ]
  -         , div [ class "content", style "color" "black" ]
  -             [ p [] [ text (shortDescription <| Maybe.withDefault "" description) ]
  -             ]
  - 
  -         -- , div [ class "card-footer", class "content" ]
  -         -- [ p []
  -         -- [ text "tags"
  -         -- ]
  -         -- ]
  -         ]
  - 
  - 
  - shortDescription : String -> String
  - shortDescription description =
  -     if String.length description <= 147 then
  -         description
  - 
  -     else
  -         String.left 150 description ++ "..."
  - 
  - 
  - viewPreviewWithoutImage : String -> Int -> Maybe String -> String -> Html Msg
  - viewPreviewWithoutImage title id description createdAt =
  -     div [ class "card" ]
  -         [ div [ class "card-head" ]
  -             [ p [ class "card-head-title", style "color" "black" ] [ text title ]
  -             ]
  -         , div [ class "content", style "color" "black" ] [ text <| Maybe.withDefault "" description ]
  -         ]
  - 
  --}


imgUrl : Int -> String
imgUrl i =
    case i of
        1 ->
            foodImgUrl "cheese+cake"

        2 ->
            foodImgUrl "blue+berry+pie"

        25 ->
            pancakeImgUrl

        26 ->
            foodImgUrl "spaghetti"

        _ ->
            foodImgUrl "food"


foodImgUrl : String -> String
foodImgUrl query =
    "url(https://source.unsplash.com/640x480/?" ++ query ++ ")"


pancakeImgUrl : String
pancakeImgUrl =
    "url(https://assets.icanet.se/q_auto,f_auto/imagevaultfiles/id_185874/cf_259/pannkakstarta-med-choklad-och-nutella-724305-stor.jpg)"



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
