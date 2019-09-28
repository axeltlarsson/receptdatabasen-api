module Page.Recipe.Form exposing (Model, Msg(..), fromRecipe, init, toJson, update, view)

import Dict
import Form exposing (Form)
import Form.Error exposing (ErrorValue(..))
import Form.Field as Field exposing (Field)
import Form.Input as Input
import Form.Validate as Validate exposing (..)
import Html exposing (..)
import Html.Attributes exposing (class, disabled, max, min, placeholder, value)
import Html.Events exposing (keyCode, onClick, onInput, preventDefaultOn)
import Json.Decode as Decode
import Json.Encode as Encode
import Recipe
import Recipe.Slug as Slug
import Regex
import Set
import Task



-- MODEL


type alias RecipeDetails =
    { title : String
    , description : Maybe String
    , portions : Int
    , instructions : String
    , ingredients : List IngredientGroup
    , newIngredientGroupInput : String
    , tags : List String
    , newTagInput : String
    }


type alias IngredientGroup =
    { group : String
    , ingredients : List String
    , newIngredientInput : String
    }


type alias RecipeForm =
    Form CustomError RecipeDetails


type CustomError
    = EmptyList


type alias Model =
    { form : RecipeForm
    }


init : ( Model, Cmd Msg )
init =
    ( { form = initialForm }, Cmd.none )


initialForm : RecipeForm
initialForm =
    Form.initial
        [ ( "portions", Field.string "4" )
        , ( "ingredients"
          , Field.list
                [ Field.group
                    [ ( "group", Field.string "Ingredienser" )
                    , ( "newIngredientInput", Field.value Field.EmptyField )
                    ]
                ]
          )
        ]
        validate


fromRecipe : Recipe.Recipe Recipe.Full -> Model
fromRecipe recipe =
    let
        { id, title, description } =
            Recipe.metadata recipe

        { instructions, tags, portions, ingredients } =
            Recipe.contents recipe

        recipeForm =
            Form.initial
                [ ( "title", Field.string <| Slug.toString title )
                , ( "description", Field.string description )
                , ( "portions", Field.string <| String.fromInt portions )
                , ( "instructions", Field.string instructions )
                , ( "ingredients", Field.list <| Dict.foldl ingredientFields [] ingredients )
                , ( "tags", Field.list <| List.map Field.string tags )
                , ( "newTagInput", Field.value Field.EmptyField )
                ]
                validate
    in
    { form = recipeForm }


ingredientFields : String -> List String -> List Field.Field -> List Field.Field
ingredientFields group ingredients groups =
    Field.group
        [ ( "group", Field.string group )
        , ( "ingredients"
          , Field.list <| List.map Field.string ingredients
          )
        ]
        :: groups


validate : Validation CustomError RecipeDetails
validate =
    succeed RecipeDetails
        -- TODO: validate title uniqueness (async against server)
        |> andMap (field "title" (trimmedString |> andThen (minLength 3) |> andThen (maxLength 100)))
        |> andMap
            (field "description"
                (oneOf
                    [ emptyString |> Validate.map (\_ -> Nothing)
                    , trimmedString |> andThen (maxLength 500) |> Validate.map Just
                    ]
                )
            )
        |> andMap (field "portions" (int |> andThen (minInt 1) |> andThen (maxInt 100)))
        |> andMap (field "instructions" (trimmedString |> andThen (minLength 5) |> andThen (maxLength 4000)))
        |> andMap (field "ingredients" (nonEmptyList validateIngredientGroups))
        |> andMap (field "newIngredientGroupInput" emptyString)
        |> andMap (field "tags" (list trimmedString))
        |> andMap (field "newTagInput" emptyString)


trimmedString : Field -> Result (Form.Error.Error e) String
trimmedString field =
    (string |> Validate.map String.trim |> andThen nonEmpty) field


nonEmptyList : Validation CustomError a -> Validation CustomError (List a)
nonEmptyList validation =
    let
        notEmpty list_ =
            case list_ of
                [] ->
                    Err (Form.Error.value <| Form.Error.CustomError EmptyList)

                _ ->
                    Ok list_
    in
    Validate.customValidation (list validation) notEmpty
        |> mapError (always (Form.Error.value (Form.Error.CustomError EmptyList)))


validateIngredientGroups : Validation CustomError IngredientGroup
validateIngredientGroups =
    succeed IngredientGroup
        |> andMap (field "group" trimmedString)
        |> andMap (field "ingredients" (nonEmptyList trimmedString))
        |> andMap (field "newIngredientInput" emptyString)


errorFor : Form.FieldState CustomError a -> Html Form.Msg
errorFor field =
    case field.liveError of
        Just error ->
            div [ class "error" ] [ text (errorString error field.path) ]

        Nothing ->
            text ""


view : Model -> Html Msg
view { form } =
    Html.map FormMsg (viewForm form)


viewForm : RecipeForm -> Html Form.Msg
viewForm form =
    let
        title =
            Form.getFieldAsString "title" form

        description =
            Form.getFieldAsString "description" form

        portions =
            Form.getFieldAsString "portions" form

        instructions =
            Form.getFieldAsString "instructions" form

        ingredients =
            Form.getListIndexes "ingredients" form

        ingredientGroups =
            Form.getFieldAsString "ingredients" form

        newIngredientGroupInput =
            Form.getFieldAsString "newIngredientGroupInput" form

        tags =
            Form.getListIndexes "tags" form

        newTagInput =
            Form.getFieldAsString "newTagInput" form

        disableSave =
            List.length (Form.getErrors form) > 0 && Form.isSubmitted form
    in
    div [ class "todo-list" ]
        [ div [ class "title" ]
            [ Input.textInput title [ placeholder "Namn på receptet..." ]
            , errorFor title
            ]
        , div [ class "description" ]
            [ Input.textArea description [ placeholder "Beskrivning..." ]
            , errorFor description
            ]
        , div [ class "portions" ]
            [ Input.baseInput "number" Field.String Form.Text portions [ min "1", max "100" ]
            , errorFor portions
            ]
        , div [ class "instructions" ]
            [ Input.textArea instructions [ placeholder "Instruktioner..." ]
            , errorFor instructions
            ]
        , div [ class "ingredients" ] <|
            List.append [ h3 [] [ text "Ingredienser" ] ]
                (List.map
                    (viewFormIngredientGroup form)
                    ingredients
                    |> List.append [ errorFor ingredientGroups ]
                )
        , div [ class "new-ingredient-group" ]
            [ Input.textInput newIngredientGroupInput
                [ placeholder "Ny ingrediensgrupp"
                , onEnter (Form.Append "ingredients")
                ]
            , errorFor newIngredientGroupInput
            ]
        , div [ class "tags" ] <|
            List.append [ h3 [] [ text "Taggar" ] ]
                (List.map
                    (viewFormTag form)
                    tags
                )
        , div [ class "new-tag-input" ]
            [ Input.textInput newTagInput
                [ placeholder "Ny tagg"
                , onEnter (Form.Append "tags")
                ]
            , errorFor newTagInput
            ]
        , button
            [ class "submit"
            , disabled disableSave
            , onClick Form.Submit
            ]
            [ text "Spara" ]
        ]


viewFormIngredientGroup : RecipeForm -> Int -> Html Form.Msg
viewFormIngredientGroup form i =
    let
        groupField =
            Form.getFieldAsString (groupIndex ++ ".group") form

        groupIndex =
            "ingredients." ++ String.fromInt i

        ingredients =
            Form.getListIndexes (groupIndex ++ ".ingredients") form
    in
    div
        [ class "ingredient-group" ]
        [ Input.textInput groupField
            [ placeholder "Grupp" ]
        , errorFor groupField
        , button
            [ class "remove-group"
            , onClick (Form.RemoveItem "ingredients" i)
            ]
            [ text "Ta bort grupp" ]
        , div [ class "ingredients" ] (List.map (viewFormIngredients form groupIndex) ingredients)
        , Input.textInput (Form.getFieldAsString (groupIndex ++ ".newIngredientInput") form)
            [ class "add-ingredient"
            , placeholder "Ny ingrediens"
            , onEnter (Form.Append (groupIndex ++ ".ingredients"))
            ]
        ]


viewFormIngredients : RecipeForm -> String -> Int -> Html Form.Msg
viewFormIngredients form groupIndex i =
    let
        index =
            groupIndex ++ ".ingredients." ++ String.fromInt i
    in
    div
        [ class "ingredient" ]
        [ Input.textInput
            (Form.getFieldAsString index form)
            []
        , button
            [ class "remove-ingredient"
            , onClick (Form.RemoveItem (groupIndex ++ ".ingredients") i)
            ]
            [ text "Ta bort ingrediens" ]
        ]


viewFormTag : RecipeForm -> Int -> Html Form.Msg
viewFormTag form i =
    div
        [ class "tag" ]
        [ Input.textInput
            (Form.getFieldAsString ("tags." ++ String.fromInt i) form)
            [ onEnter (Form.Append "tags")
            ]
        , button
            [ class "remove"
            , onClick (Form.RemoveItem "tags" i)
            ]
            [ text "Remove" ]
        ]


onEnter : msg -> Attribute msg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                Decode.succeed ( msg, True )

            else
                Decode.fail "not ENTER"
    in
    preventDefaultOn "keydown" (Decode.andThen isEnter keyCode)


errorString : ErrorValue CustomError -> String -> String
errorString error msg =
    case error of
        Empty ->
            "fältet får ej vara tomt"

        SmallerIntThan i ->
            "måste vara minst " ++ String.fromInt i

        GreaterIntThan i ->
            "får vara max " ++ String.fromInt i

        ShorterStringThan i ->
            "måste vara minst " ++ String.fromInt i

        LongerStringThan i ->
            "får vara max " ++ String.fromInt i ++ " tecken lång"

        Form.Error.CustomError EmptyList ->
            "får ej vara tom"

        _ ->
            "är ogiltig"



-- UPDATE


type Msg
    = FormMsg Form.Msg
    | SubmitValidForm Encode.Value


appendPrefilledValue : RecipeForm -> String -> String -> String -> RecipeForm
appendPrefilledValue form inputFieldName listName destination =
    let
        newValue =
            Maybe.withDefault "" (Form.getFieldAsString inputFieldName form).value

        appendedForm =
            Form.update validate (Form.Append listName) form

        index =
            (List.length <| Form.getListIndexes listName appendedForm) - 1

        inputMsg =
            Form.Input (String.concat [ listName, ".", String.fromInt index, destination ]) Form.Text (Field.String newValue)

        resetMsg =
            Form.Input inputFieldName Form.Text (Field.String "")
    in
    if String.isEmpty newValue then
        form

    else
        appendedForm |> Form.update validate inputMsg |> Form.update validate resetMsg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ form } as model) =
    case msg of
        FormMsg (Form.Append listName) ->
            case listName of
                "tags" ->
                    ( { model
                        | form = appendPrefilledValue form "newTagInput" "tags" ""
                      }
                    , Cmd.none
                    )

                "ingredients" ->
                    ( { model
                        | form = appendPrefilledValue form "newIngredientGroupInput" "ingredients" ".group"
                      }
                    , Cmd.none
                    )

                nestedIngredients ->
                    let
                        nestedIndex =
                            nestedIngredientIndex nestedIngredients
                    in
                    case nestedIndex of
                        Just i ->
                            let
                                inputFieldName =
                                    "ingredients." ++ i ++ ".newIngredientInput"
                            in
                            ( { model
                                | form = appendPrefilledValue form inputFieldName nestedIngredients ""
                              }
                            , Cmd.none
                            )

                        _ ->
                            ( model, Cmd.none )

        FormMsg Form.Submit ->
            case toJson model of
                Just jsonForm ->
                    ( { model | form = Form.update validate Form.Submit form }
                    , Task.succeed (SubmitValidForm jsonForm) |> Task.perform identity
                    )

                Nothing ->
                    ( { model | form = Form.update validate Form.Submit form }
                    , Cmd.none
                    )

        FormMsg (Form.Blur field) ->
            {--
              - When blurring certain fields - append the input as a help to users
              --}
            case field of
                "newTagInput" ->
                    update (FormMsg (Form.Append "tags")) model

                "newIngredientGroupInput" ->
                    update (FormMsg (Form.Append "ingredients")) model

                maybeIngredientField ->
                    let
                        regex =
                            Maybe.withDefault Regex.never <| Regex.fromString "ingredients.(\\d+).newIngredientInput"

                        matches =
                            List.map .submatches <| Regex.find regex maybeIngredientField
                    in
                    case matches of
                        [ [ Just i ] ] ->
                            update (FormMsg (Form.Append ("ingredients." ++ i ++ ".ingredients"))) model

                        _ ->
                            ( model, Cmd.none )

        FormMsg formMsg ->
            ( { model | form = Form.update validate formMsg form }, Cmd.none )

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
    Maybe.map
        (\recipe ->
            Encode.object <|
                maybeAddDescription
                    [ ( "title", Encode.string recipe.title )
                    , ( "instructions", Encode.string recipe.instructions )
                    , ( "portions", Encode.string (portionsString recipe) )
                    , ( "tags", Encode.set Encode.string <| Set.fromList recipe.tags )
                    , ( "ingredients", Encode.dict identity (Encode.list Encode.string) (ingredientDict recipe) )
                    ]
                    recipe
        )
        (Form.getOutput form)


nestedIngredientIndex : String -> Maybe String
nestedIngredientIndex str =
    let
        regex =
            Maybe.withDefault Regex.never <| Regex.fromString "ingredients.(\\d+).ingredients"

        matches =
            List.map .submatches <| Regex.find regex str
    in
    case matches of
        [ [ Just i ] ] ->
            Just i

        _ ->
            Nothing
