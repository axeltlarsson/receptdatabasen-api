module Page.Test exposing (Model, Msg, init, toSession, update, view)

import Form exposing (Form)
import Form.Error exposing (ErrorValue(..))
import Form.Field as Field exposing (Field)
import Form.Input as Input
import Form.Validate as Validate exposing (..)
import Html exposing (..)
import Html.Attributes exposing (class, max, min, placeholder, value)
import Html.Events exposing (keyCode, onClick, onInput, preventDefaultOn)
import Json.Decode as Decode
import Session exposing (Session)



-- MODEL
-- expected form output


type alias RecipeForm =
    { title : String
    , description : Maybe String
    , portions : Int
    , tags : List String
    , instructions : String
    , newTagInput : String
    , ingredients : List IngredientGroup
    }


type alias IngredientGroup =
    { group : String
    , ingredients : List String
    }


type alias Model =
    { session : Session
    , form : Form () RecipeForm
    }



-- setup form validation


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session, form = Form.initial [] validate }, Cmd.none )


validate : Validation () RecipeForm
validate =
    succeed RecipeForm
        -- TODO: validate title uniqueness (async against server)
        |> andMap (field "title" (string |> andThen (minLength 3) |> andThen (maxLength 512)))
        -- TODO: maybe removes the error...
        |> andMap (field "description" (maybe (string |> andThen (maxLength 500))))
        |> andMap (field "portions" (int |> andThen (minInt 1) |> andThen (maxInt 100)))
        |> andMap (field "tags" (list string))
        |> andMap (field "instructions" (string |> andThen (minLength 5) |> andThen (maxLength 4000)))
        |> andMap (field "newTagInput" string)
        |> andMap (field "ingredients" (list validateIngredientGroups))


validateIngredientGroups : Validation () IngredientGroup
validateIngredientGroups =
    succeed IngredientGroup
        |> andMap (field "group" string)
        |> andMap (field "ingredients" (list string))



-- TODO: ignore probably?
-- render form with Input helpers


view : Model -> { title : String, content : Html Msg }
view { form } =
    { title = "Test"
    , content = div [] [ Html.map FormMsg (viewForm form) ]
    }


viewForm : Form () RecipeForm -> Html Form.Msg
viewForm form =
    let
        errorFor field =
            case field.liveError of
                Just error ->
                    div [ class "error" ] [ text (errorString error field.path) ]

                Nothing ->
                    text ""

        title =
            Form.getFieldAsString "title" form

        description =
            Form.getFieldAsString "description" form

        portions =
            Form.getFieldAsString "portions" form

        tags =
            Form.getListIndexes "tags" form

        instructions =
            Form.getFieldAsString "instructions" form

        newTagInput =
            Form.getFieldAsString "newTagInput" form

        ingredients =
            Form.getListIndexes "ingredients" form
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
        , div [ class "tags" ] <|
            List.append [ h3 [] [ text "Taggar" ] ]
                (List.map
                    (viewTag form)
                    tags
                )
        , div [ class "new-tag-input" ]
            [ Input.textInput newTagInput
                [ placeholder "Ny tagg"
                , onEnter (Form.Append "tags")
                ]
            , errorFor title
            ]
        , div [ class "ingrediens" ] <|
            List.append [ h3 [] [ text "Ingredienser" ] ]
                (List.map
                    (viewIngredientGroup form)
                    ingredients
                )
        , button [ onClick (Form.Append "ingredients") ] [ text "New ingredient group" ]
        , button
            [ class "submit"
            , onClick Form.Submit
            ]
            [ text "Spara" ]
        ]


viewTag : Form () RecipeForm -> Int -> Html Form.Msg
viewTag form i =
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


viewIngredientGroup : Form () RecipeForm -> Int -> Html Form.Msg
viewIngredientGroup form i =
    let
        groupIndex =
            "ingredients." ++ String.fromInt i

        ingredients =
            Form.getListIndexes (groupIndex ++ ".ingredients") form
    in
    div
        [ class "ingredient-group" ]
        [ Input.textInput
            (Form.getFieldAsString (groupIndex ++ ".group") form)
            [ placeholder "Grupp" ]
        , button
            [ class "remove"
            , onClick (Form.RemoveItem "ingredients" i)
            ]
            [ text "Remove" ]
        , button
            [ class "add-ingredient"
            , onClick (Form.Append (groupIndex ++ ".ingredients"))
            ]
            [ text "Add ingredient" ]
        , div [ class "ingredients" ] (List.map (viewIngredients form groupIndex) ingredients)
        ]


viewIngredients : Form () RecipeForm -> String -> Int -> Html Form.Msg
viewIngredients form groupIndex i =
    let
        index =
            groupIndex ++ ".ingredients." ++ String.fromInt i
    in
    div
        [ class "ingredient" ]
        [ Input.textInput
            (Form.getFieldAsString index form)
            []
        , button [ class "remove", onClick (Form.RemoveItem (groupIndex ++ ".ingredients") i) ] [ text "remove" ]
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


errorString : ErrorValue e -> String -> String
errorString error msg =
    case error of
        Empty ->
            msg ++ " får ej vara tom"

        SmallerIntThan i ->
            msg ++ " måste vara minst " ++ String.fromInt i

        GreaterIntThan i ->
            msg ++ " får vara max " ++ String.fromInt i

        ShorterStringThan i ->
            msg ++ " måste vara minst " ++ String.fromInt i

        LongerStringThan i ->
            msg ++ " måste vara minst " ++ String.fromInt i

        _ ->
            msg ++ " är ogiltig"


type Msg
    = FormMsg Form.Msg



-- TODO: use this or not?


appendWithDefault : Form () RecipeForm -> String -> String -> Form () RecipeForm
appendWithDefault form inputField list =
    let
        newValue =
            Maybe.withDefault "" (Form.getFieldAsString inputField form).value

        appendedForm =
            Form.update validate (Form.Append list) form

        index =
            (List.length <| Form.getListIndexes list appendedForm) - 1

        inputMsg =
            Form.Input (String.concat [ list, ".", String.fromInt index ]) Form.Text (Field.String newValue)

        resetMsg =
            Form.Input inputField Form.Text (Field.String "")
    in
    appendedForm |> Form.update validate inputMsg |> Form.update validate resetMsg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ form } as model) =
    case msg of
        FormMsg (Form.Append "tags") ->
            let
                newTagInput =
                    Form.getFieldAsString "newTagInput" form

                newTagInputStr =
                    Maybe.withDefault "" newTagInput.value

                appendedForm =
                    Form.update validate (Form.Append "tags") form

                tags =
                    (List.length <| Form.getListIndexes "tags" appendedForm) - 1

                inputMsg =
                    Form.Input ("tags." ++ String.fromInt tags) Form.Text (Field.String newTagInputStr)

                resetMsg =
                    Form.Input "newTagInput" Form.Text (Field.String "")
            in
            if String.isEmpty newTagInputStr then
                ( model, Cmd.none )

            else
                ( { model | form = appendedForm |> Form.update validate inputMsg |> Form.update validate resetMsg }, Cmd.none )

        FormMsg formMsg ->
            ( { model | form = Form.update validate formMsg form }, Cmd.none )


toSession : Model -> Session
toSession { session } =
    session
