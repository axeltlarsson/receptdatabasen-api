module Page.Recipe.Form exposing (Model, Msg(..), fromRecipe, init, portMsg, toJson, update, view)

import Dict exposing (Dict)
import Element exposing (Element, alignBottom, alignLeft, alignRight, alignTop, centerX, centerY, column, el, fill, height, padding, paragraph, rgb255, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode
import Mark
import Mark.Error
import Palette
import Recipe
import Recipe.Slug as Slug
import Regex
import Set
import Task


viewInstructionsEditor : Html Msg
viewInstructionsEditor =
    let
        options =
            """
        {
            "toolbar": ["heading-1"]
        }
        """
    in
    Html.node "easy-mde"
        [ Html.Attributes.id "instructions-editor"
        , Html.Attributes.attribute "placeholder" "Gör så här"
        , Html.Attributes.attribute "options" options
        ]
        []


viewIngredientsEditor : Html Msg
viewIngredientsEditor =
    let
        options =
            """
        {
            "toolbar": ["heading-2"]
        }
        """
    in
    Html.node "easy-mde"
        [ Html.Attributes.id "ingredients-editor"
        , Html.Attributes.attribute "placeholder" "Fyll i en lista av ingredienser"
        , Html.Attributes.attribute "options" options
        ]
        []



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
    ( { form = initialForm
      }
    , Task.succeed (SendPortMsg (Encode.object [ ( "editorElemId", Encode.string "mde-editor" ) ])) |> Task.perform identity
    )


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
    column [ Region.mainContent, width fill ]
        [ viewForm form
        ]


viewForm : RecipeForm -> Element Msg
viewForm form =
    column [ width fill, spacing 30, padding 10, Font.extraLight ]
        [ column [ width (fill |> Element.maximum 700), centerX, spacing 30 ]
            [ viewTitleInput form.title
            , viewDescriptionInput form.description
            , viewPortionsInput form.portions
            , el [ Font.size 36, Font.semiBold ] (text "Gör så här")
            , el [ height fill, width fill ] (Element.html viewInstructionsEditor)
            , el [ height fill, width fill ] (Element.html viewIngredientsEditor)
            , viewInstructionsInput form.instructions
            , column [ width fill, spacing 20 ]
                [ el [ Font.size 20 ] (text "Ingredienser")
                , viewIngredientsInput form.ingredients
                ]
            ]
        ]


debug : Element.Attribute Msg
debug =
    Element.explain Debug.todo


viewDescriptionInput : String -> Element Msg
viewDescriptionInput description =
    Input.multiline
        [ height (fill |> Element.minimum 120 |> Element.maximum 240) ]
        { onChange = DescriptionChanged
        , text = description
        , placeholder = Just (Input.placeholder [] (el [] (text "Beskriv receptet med en trevlig introduktion...")))
        , label = Input.labelHidden "Beskrivning"
        , spellcheck = True
        }


viewTitleInput : String -> Element Msg
viewTitleInput title =
    Input.text
        [ Font.bold
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
                , Background.color Palette.grey
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
        [ height (fill |> Element.minimum 120 |> Element.maximum 240) ]
        { onChange = InstructionsChanged
        , text = instructions
        , placeholder = Just (Input.placeholder [] (el [] (text "Gör så här...")))
        , label = Input.labelHidden "Instruktioner"
        , spellcheck = True
        }


viewIngredientsInput : String -> Element Msg
viewIngredientsInput instructions =
    Input.multiline
        []
        { onChange = IngredientsChanged
        , text = instructions
        , placeholder = Just (Input.placeholder [] (el [] (text "- Ingredienser")))
        , label = Input.labelHidden "Ingredienser"
        , spellcheck = True
        }



-- UPDATE


type Msg
    = TitleChanged String
    | DescriptionChanged String
    | PortionsChanged Int
    | InstructionsChanged String
    | IngredientsChanged String
    | SubmitForm
    | SubmitValidForm Encode.Value
    | PortMsgReceived Decode.Value
    | SendPortMsg Encode.Value


portMsg : Decode.Value -> Msg
portMsg =
    PortMsgReceived


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
            -- Editor deals with this
            ( model, Cmd.none )

        PortMsgReceived m ->
            case Decode.decodeValue portMsgDecoder m of
                Err err ->
                    Debug.log (Decode.errorToString err)
                        ( model, Cmd.none )

                Ok (InstructionsChange value) ->
                    ( { model | form = { form | instructions = value } }, Cmd.none )

                Ok (IngredientsChange value) ->
                    ( { model | form = { form | ingredients = value } }, Cmd.none )

        SendPortMsg x ->
            -- Editor deals with this
            ( model, Cmd.none )


type PortMsg
    = InstructionsChange String
    | IngredientsChange String


portMsgDecoder : Decode.Decoder PortMsg
portMsgDecoder =
    Decode.field "type" Decode.string |> Decode.andThen typeDecoder


typeDecoder : String -> Decode.Decoder PortMsg
typeDecoder t =
    case t of
        "change" ->
            Decode.field "id" Decode.string |> Decode.andThen changeDecoder

        _ ->
            Decode.fail ("trying to decode port message, but " ++ t ++ "is not supported")


changeDecoder : String -> Decode.Decoder PortMsg
changeDecoder id =
    case id of
        "ingredients-editor" ->
            Decode.map IngredientsChange
                (Decode.field "value" Decode.string)

        "instructions-editor" ->
            Decode.map InstructionsChange
                (Decode.field "value" Decode.string)

        _ ->
            Decode.fail ("trying to decode change message, but " ++ id ++ " is not supported")


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
