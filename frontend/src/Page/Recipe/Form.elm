module Page.Recipe.Form exposing (Model, Msg(..), fromRecipe, init, toJson, update, view)

-- import Html.Attributes as Attr exposing (class, classList, disabled, height, id, max, min, placeholder, value, width)
-- import Html.Events exposing (keyCode, on, onClick, onInput, preventDefaultOn, stopPropagationOn, targetValue)

import Dict
import Element exposing (Element, alignBottom, alignLeft, alignRight, alignTop, centerX, centerY, column, el, fill, height, padding, paragraph, rgb255, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Json.Decode as Decode
import Json.Encode as Encode
import Mark
import Mark.Error
import Recipe
import Recipe.Slug as Slug
import Regex
import Set
import Task


markup : String -> Element Msg
markup source =
    case Mark.compile document source of
        Mark.Success elem ->
            el [] elem

        Mark.Almost { result, errors } ->
            -- This is the case where there has been an error,
            -- but it has been caught by `Mark.onError` and is still rendereable.
            row []
                [ el [] (viewErrors errors)
                , el [] result
                ]

        Mark.Failure errors ->
            row [ Background.color grey ]
                [ viewErrors errors
                ]


viewErrors : List Mark.Error.Error -> Element Msg
viewErrors errors =
    row []
        (List.map
            (Mark.Error.toString >> text)
            errors
        )


document : Mark.Document (Element Msg)
document =
    Mark.document
        (\title -> title)
        (Mark.oneOf
            [ titleBlock
            , list
            ]
        )


titleBlock : Mark.Block (Element Msg)
titleBlock =
    Mark.block "Ingredienser"
        (\str -> el [] (text str))
        Mark.string


markText : Mark.Block (List (Element Msg))
markText =
    Mark.text
        (\styles string ->
            Element.text string
         {--
              - Html.span
              -     [ Html.Attributes.classList
              -         [ ( "bold", styles.bold )
              -         , ( "italic", styles.italic )
              -         , ( "strike", styles.strike )
              -         ]
              -     ]
              -     [ Html.text string ]
              --}
        )


list : Mark.Block (Element Msg)
list =
    Mark.tree "List" renderList (Mark.map (row []) markText)



-- Note: we have to define this as a separate function because
-- `Items` and `Node` are a pair of mutually recursive data structures.
-- It's easiest to render them using two separate functions:
-- renderList and renderItem


renderList : Mark.Enumerated (Element Msg) -> Element Msg
renderList (Mark.Enumerated enum) =
    let
        group =
            case enum.icon of
                Mark.Bullet ->
                    Font.color grey

                Mark.Number ->
                    Font.color red
    in
    column [ group ]
        (List.map renderItem enum.items)


renderItem : Mark.Item (Element Msg) -> Element Msg
renderItem (Mark.Item item) =
    column [ padding 30 ]
        [ row [] item.content
        , renderList item.children
        ]



-- MODEL


type alias RecipeForm =
    { title : String
    , description : String
    , portions : Int
    , instructions : String
    , ingredients : String

    -- , newIngredientGroupInput : String
    -- , tags : List String
    -- , newTagInput : String
    }


type alias Model =
    { form : RecipeForm
    }


init : ( Model, Cmd Msg )
init =
    ( { form = initialForm }, Cmd.none )


initialForm : RecipeForm
initialForm =
    { title = ""
    , description = ""
    , portions = 4
    , instructions = ""
    , ingredients = """|> List
    - Ingredienser
        - 1 kg mjöl
        - 1 kg mjölk
    - Tillbehör
        - koriander"""
    }


fromRecipe : Recipe.Recipe Recipe.Full -> Model
fromRecipe recipe =
    let
        { id, title, description } =
            Recipe.metadata recipe

        { instructions, tags, portions, ingredients } =
            Recipe.contents recipe

        {--
          - descriptionField =
          -     (Maybe.map Field.string >> Maybe.withDefault (Field.value Field.EmptyField)) description
          --}
        {--
          - recipeForm =
          -     Form.initial
          -         [ ( "title", Field.string <| Slug.toString title )
          -         , ( "description", descriptionField )
          -         , ( "portions", Field.string <| String.fromInt portions )
          -         , ( "instructions", Field.string instructions )
          -         , ( "ingredients", Field.list <| Dict.foldl ingredientFields [] ingredients )
          -         , ( "tags", Field.list <| List.map Field.string tags )
          -         , ( "newTagInput", Field.value Field.EmptyField )
          -         ]
          -         validate
          --}
    in
    { form =
        { title = Slug.toString title
        , description = Maybe.withDefault "" description
        , portions = portions
        , instructions = instructions
        , ingredients = "" -- TODO
        }
    }



{--
  - validate : Validation CustomError RecipeDetails
  - validate =
  -     succeed RecipeDetails
  -         -- TODO: validate title uniqueness (async against server)
  -         |> andMap (field "title" (trimmedTitle |> andThen (minLength 3) |> andThen (maxLength 100)))
  -         |> andMap
  -             (field "description"
  -                 (oneOf
  -                     [ emptyString |> Validate.map (\_ -> Nothing)
  -                     , trimmedString |> andThen (maxLength 500) |> Validate.map Just
  -                     ]
  -                 )
  -             )
  -         |> andMap (field "portions" (int |> andThen (minInt 1) |> andThen (maxInt 100)))
  -         |> andMap (field "instructions" (trimmedString |> andThen (minLength 5) |> andThen (maxLength 4000)))
  -         |> andMap (field "ingredients" (nonEmptyList validateIngredientGroups))
  -         |> andMap (field "newIngredientGroupInput" emptyString)
  -         |> andMap (field "tags" (list trimmedString))
  -         |> andMap (field "newTagInput" emptyString)
  --}
{--
  - validateIngredientGroups : Validation CustomError IngredientGroup
  - validateIngredientGroups =
  -     succeed IngredientGroup
  -         |> andMap (field "group" trimmedString)
  -         |> andMap (field "ingredients" (nonEmptyList trimmedString))
  -         |> andMap (field "newIngredientInput" emptyString)
  --}
{--
  - errorFor : Form.FieldState CustomError a -> Element Form.Msg
  - errorFor field =
  -     case field.liveError of
  -         Just error ->
  -             -- div [ class "error text-danger" ] [ text (errorString error field.path) ]
  -             el [] (text (errorString error field.path))
  -
  -         Nothing ->
  -             text ""
  -
  --}


view : Model -> Element Msg
view { form } =
    column [ Region.mainContent ] [ viewForm form ]


viewForm : RecipeForm -> Element Msg
viewForm form =
    column [ width fill, spacing 30, padding 10 ]
        [ column [ width (fill |> Element.maximum 700), centerX, spacing 30 ]
            [ viewTitleInput form.title
            , viewDescriptionInput form.description
            , viewPortionsInput form.portions
            , viewInstructionsInput form.instructions
            , column [ width fill, spacing 20 ]
                [ el [ Font.size 20 ] (text "Ingredienser")
                , viewIngredientsInput form.ingredients
                , markup form.ingredients
                ]
            ]
        ]


debug : Element.Attribute Msg
debug =
    Element.explain Debug.todo


viewDescriptionInput : String -> Element Msg
viewDescriptionInput description =
    Input.multiline
        [ height (Element.px 120) ]
        { onChange = DescriptionChanged
        , text = description
        , placeholder = Just (Input.placeholder [] (el [] (text "Beskriv receptet med en trevlig introduktion...")))
        , label = Input.labelHidden "Beskrivning"
        , spellcheck = True
        }


viewTitleInput : String -> Element Msg
viewTitleInput title =
    Input.text
        [ Input.focusedOnLoad
        ]
        { onChange = TitleChanged
        , text = title
        , placeholder = Just (Input.placeholder [] (el [] (text "Titel")))
        , label = Input.labelHidden "Titel"
        }


viewPortionsInput : Int -> Element Msg
viewPortionsInput portions =
    Input.slider
        [ Element.height (Element.px 30)

        -- Here is where we're creating/styling the "track"
        , Element.behindContent
            (Element.el
                [ Element.width Element.fill
                , Element.height (Element.px 2)
                , Element.centerY
                , Background.color grey
                , Border.rounded 2
                ]
                Element.none
            )
        ]
        { onChange = round >> PortionsChanged
        , label =
            Input.labelAbove []
                (text ("Portioner: " ++ String.fromInt portions))
        , min = 0
        , max = 75
        , step = Just 1
        , value = toFloat portions
        , thumb =
            Input.defaultThumb
        }


viewInstructionsInput : String -> Element Msg
viewInstructionsInput instructions =
    Input.multiline
        [ height (Element.px 120) ]
        { onChange = InstructionsChanged
        , text = instructions
        , placeholder = Just (Input.placeholder [] (el [] (text "Gör så här...")))
        , label = Input.labelHidden "Instruktioner"
        , spellcheck = True
        }


viewIngredientsInput : String -> Element Msg
viewIngredientsInput instructions =
    Input.multiline
        [ height (Element.px 120) ]
        { onChange = IngredientsChanged
        , text = instructions
        , placeholder = Just (Input.placeholder [] (el [] (text "- Ingredienser")))
        , label = Input.labelHidden "Ingredienser"
        , spellcheck = True
        }


white : Element.Color
white =
    rgb255 0 0 0


grey : Element.Color
grey =
    rgb255 104 92 93


red : Element.Color
red =
    rgb255 255 0 0



{--
  -
  -     div [ class "recipe-form animated fadeIn" ]
  -         [ div [ class "title input-control" ]
  -             [ Input.textInput title [ class "input-xlarge", placeholder "Namn på receptet..." ]
  -             , errorFor title
  -             ]
  -         , div [ class "description input-control" ]
  -             [ Input.textArea description [ placeholder "Beskrivning..." ]
  -             , errorFor description
  -             ]
  -         , div [ class "portions form-section row u-no-padding" ] <| viewPortionsSection form
  -         , div [ class "instructions input-control" ]
  -             [ Input.textArea instructions [ placeholder "Instruktioner..." ]
  -             , errorFor instructions
  -             ]
  -         , div [ class "ingredients form-section animated fadeIn" ] <| viewIngredientsSection form
  -         , div [ class "tags form-section" ] <| viewTagsSection form
  -         , div [ class "submit form-section" ]
  -             [ button
  -                 [ class "submit btn btn-dark btn-animated"
  -                 , disabled disableSave
  -                 , onClick Form.Submit
  -                 ]
  -                 [ text "Spara" ]
  -             ]
  -             ]
  -
  -
  --}
{--
  - viewPortionsSection : RecipeForm -> List (Html Form.Msg)
  - viewPortionsSection form =
  -     let
  -         portions =
  -             Form.getFieldAsString "portions" form
  -     in
  -         [ div [ class "col-1 form-section section-inline" ]
  -         [ label [ class "font-normal" ] [ text "Portioner:" ]
  -         , Input.baseInput "number" Field.String Form.Text portions [ Attr.min "1", Attr.max "100" ]
  -         , errorFor portions
  -         ]
  -         ]
  -
  -
  - viewIngredientsSection : RecipeForm -> List (Html Form.Msg)
  - viewIngredientsSection form =
  -     let
  -         ingredients =
  -             Form.getListIndexes "ingredients" form
  -
  -         ingredientGroups =
  -             Form.getFieldAsString "ingredients" form
  -
  -         newIngredientGroupInput =
  -             Form.getFieldAsString "newIngredientGroupInput" form
  -     in
  -         [ div [ class "ingredient-groups form-section row" ] <|
  -             List.append [ h3 [ class "col-12" ] [ text "Ingredienser" ] ]
  -             (List.map
  -             (viewFormIngredientGroup form)
  -             ingredients
  -             |> List.append [ errorFor ingredientGroups ]
  -     , div [ class "row" ]
  -         [ div [ class "new-ingredient-group col-12 form-group" ]
  -             [ Input.textInput newIngredientGroupInput
  -                 [ placeholder "Ny ingrediensgrupp..."
  -                 , onEnter (Form.Append "ingredients")
  -                 , class "form-group-input"
  -                 ]
  -             , button
  -                 [ class "form-group-btn btn btn-dark btn-animated"
  -                 , onClick (Form.Append "ingredients")
  -                 ]
  -                 [ icon "add" ]
  -             ]
  -         , errorFor newIngredientGroupInput
  -         ]
  -     ]
  -
  -
  - viewFormIngredientGroup : RecipeForm -> Int -> Html Form.Msg
  - viewFormIngredientGroup form i =
  -     let
  -         groupField =
  -             Form.getFieldAsString (groupIndex ++ ".group") form
  -
  -         groupIndex =
  -             "ingredients." ++ String.fromInt i
  -
  -         ingredients =
  -             Form.getListIndexes (groupIndex ++ ".ingredients") form
  -     in
  -     div [ class "form-section ingredient-group col-6 animated fadeIn" ]
  -         [ div [ class "form-group" ]
  -             [ Input.textInput groupField
  -                 [ class "form-group-input input font-bold", placeholder "Grupp" ]
  -             , errorFor groupField
  -             , button
  -                 [ class "remove-group form-group-btn btn btn-animated"
  -                 , onClick (Form.RemoveItem "ingredients" i)
  -                 ]
  -                 [ icon "close" ]
  -             ]
  -         , div [ class "ingredients" ] (List.map (viewFormIngredient form groupIndex) ingredients)
  -         , div [ class "form-group" ]
  -             [ Input.textInput (Form.getFieldAsString (groupIndex ++ ".newIngredientInput") form)
  -                 [ class "form-group-input add-ingredient"
  -                 , placeholder "Ny ingrediens..."
  -                 , onEnter (Form.Append (groupIndex ++ ".ingredients"))
  -                 ]
  -             , button
  -                 [ class "form-group-btn btn btn-dark btn-animated"
  -                 , onClick (Form.Append (groupIndex ++ ".ingredients"))
  -                 ]
  -                 [ icon "add" ]
  -             ]
  -         ]
  -
  -
  - icon : String -> Html Form.Msg
  - icon iconStr =
  -     i [ class "material-icons" ] [ text iconStr ]
  -
  -
  - viewFormIngredient : RecipeForm -> String -> Int -> Html Form.Msg
  - viewFormIngredient form groupIndex i =
  -     let
  -         index =
  -             groupIndex ++ ".ingredients." ++ String.fromInt i
  -     in
  -     div
  -         [ class "form-group ingredient animated fadeIn" ]
  -         [ Input.textInput (Form.getFieldAsString index form) [ class "form-group-input" ]
  -         , button
  -             [ class "remove form-group-btn btn btn-animated"
  -             , onClick (Form.RemoveItem (groupIndex ++ ".ingredients") i)
  -             ]
  -             [ icon "close" ]
  -         ]
  -
  -
  - viewTagsSection : RecipeForm -> List (Html Form.Msg)
  - viewTagsSection form =
  -     let
  -         tagsIndcs =
  -             Form.getListIndexes "tags" form
  -
  -         newTagInput =
  -             Form.getFieldAsString "newTagInput" form
  -
  -         tags =
  -             List.map (viewFormTag form) tagsIndcs
  -     in
  -     [ div [ class "form-section row" ]
  -         (List.concat
  -             [ [ h3 [ class "col-12" ] [ text "Taggar" ] ]
  -             , tags
  -             ]
  -         )
  -     , div [ class "row" ]
  -         [ div [ class "form-group col-12 new-tag-input" ]
  -             [ Input.textInput newTagInput
  -                 [ placeholder "Ny tagg..."
  -                 , onEnter (Form.Append "tags")
  -                 , class "form-group-input"
  -                 ]
  -             , button
  -                 [ class "form-group-btn btn btn-dark btn-animated"
  -                 , onClick (Form.Append "tags")
  -                 ]
  -                 [ icon "add" ]
  -             ]
  -         , errorFor newTagInput
  -         ]
  -     ]
  -
  -
  - viewFormTag : RecipeForm -> Int -> Html Form.Msg
  - viewFormTag form i =
  -     div [ class "col-4 animated fadeIn" ]
  -         [ div
  -             [ class "form-group tagg" ]
  -             -- "tagg" to avoid Cirrus conflict with "tag"
  -             [ Input.textInput (Form.getFieldAsString ("tags." ++ String.fromInt i) form) [ class "form-group-input" ]
  -             , button
  -                 [ class "remove form-group-btn btn btn-animated"
  -                 , onClick (Form.RemoveItem "tags" i)
  -                 ]
  -                 [ icon "close" ]
  -             ]
  -         ]
  --}
-- onEnter : msg -> Attribute msg
-- onEnter msg =
-- let
-- isEnter code =
-- if code == 13 then
-- Decode.succeed ( msg, True )
-- else
-- Decode.fail "not ENTER"
-- in
-- preventDefaultOn "keydown" (Decode.andThen isEnter keyCode)
{--
  -
  - errorString : ErrorValue CustomError -> String -> String
  - errorString error msg =
  -     case error of
  -         Empty ->
  -             "fältet får ej vara tomt"
  -
  -         SmallerIntThan i ->
  -             "måste vara minst " ++ String.fromInt i
  -
  -         GreaterIntThan i ->
  -             "får vara max " ++ String.fromInt i
  -
  -         ShorterStringThan i ->
  -             "måste vara minst " ++ String.fromInt i ++ " tecken lång"
  -
  -         LongerStringThan i ->
  -             "får vara max " ++ String.fromInt i ++ " tecken lång"
  -
  -         Form.Error.CustomError EmptyList ->
  -             "får ej vara tom"
  -
  -         _ ->
  -             "är ogiltig"
  -
  -
  --}
-- UPDATE


type Msg
    = TitleChanged String
    | DescriptionChanged String
    | PortionsChanged Int
    | InstructionsChanged String
    | IngredientsChanged String
    | SubmitForm
    | SubmitValidForm Encode.Value


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ form } as model) =
    case msg of
        TitleChanged title ->
            ( { model | form = { form | title = title } }
            , Cmd.none
            )

        DescriptionChanged description ->
            ( { model | form = { form | description = description } }
            , Cmd.none
            )

        PortionsChanged portions ->
            ( { model | form = { form | portions = portions } }
            , Cmd.none
            )

        InstructionsChanged instructions ->
            ( { model | form = { form | instructions = instructions } }
            , Cmd.none
            )

        IngredientsChanged ingredients ->
            ( { model | form = { form | ingredients = ingredients } }
            , Cmd.none
            )

        SubmitForm ->
            case toJson model of
                Just jsonForm ->
                    ( model
                      --| form = Form.update validate Form.Submit form }
                    , Task.succeed (SubmitValidForm jsonForm) |> Task.perform identity
                    )

                Nothing ->
                    ( model
                      --| form = Form.update validate Form.Submit form }
                    , Cmd.none
                    )

        SubmitValidForm _ ->
            ( model, Cmd.none )


toJson : Model -> Maybe Encode.Value
toJson { form } =
    let
        portionsString recipe =
            String.fromInt recipe.portions

        ingredientTuple { group, ingredients, newIngredientInput } =
            ( group, ingredients )

        ingredientDict recipe =
            Dict.fromList <| List.map ingredientTuple recipe.ingredients

        maybeAddDescription l recipe =
            case recipe.description of
                Just descr ->
                    l ++ [ ( "description", Encode.string descr ) ]

                Nothing ->
                    l
    in
    Just
        (Encode.object <|
            [ ( "title", Encode.string form.title )

            {--
            - , ( "instructions", Encode.string recipe.instructions )
            - , ( "portions", Encode.string (portionsString recipe) )
            - , ( "tags", Encode.set Encode.string <| Set.fromList recipe.tags )
            - , ( "ingredients", Encode.dict identity (Encode.list Encode.string) (ingredientDict recipe) )
            --}
            ]
        )
