module Page.Recipe.Form exposing (Model, Msg(..), fromRecipe, init, portMsg, toJson, update, view)

import Dict exposing (Dict)
import Element exposing (Element, alignBottom, alignLeft, alignRight, alignTop, centerX, centerY, column, el, fill, height, padding, paddingEach, paragraph, rgb255, row, spacing, text, width)
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
import Palette
import Recipe
import Recipe.Slug as Slug
import Regex
import Set
import String.Verify
import Task
import Verify



-- MODEL


type alias RecipeForm =
    { title : String
    , description : String
    , portions : Int
    , instructions : String
    , ingredients : String
    , tags : List String

    -- , newTagInput : String
    }


type alias Model =
    { form : RecipeForm
    }


init : ( Model, Cmd Msg )
init =
    ( { form = initialForm
      }
    , Cmd.none
    )


initialForm : RecipeForm
initialForm =
    { title = ""
    , description = ""
    , portions = 4
    , instructions = ""
    , ingredients = ""
    , tags = []
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
        , ingredients = ingredients
        , tags = tags
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
    column [ width (fill |> Element.maximum 700), centerX, spacing 20, padding 10, Font.extraLight ]
        [ viewTitleInput form.title
        , viewDescriptionInput form.description
        , viewPortionsInput form.portions
        , el [ Font.size 36, Font.semiBold ] (text "Gör så här")
        , viewInstructionsEditor form.instructions
        , viewSingleValidationError form.instructions instructionsValidator
        , el [ Font.size 36, Font.semiBold ] (text "Ingredienser")
        , viewIngredientsEditor form.ingredients
        , viewSingleValidationError form.ingredients ingredientsValidator
        , viewSaveButton
        ]


edges =
    { top = 0
    , right = 0
    , bottom = 0
    , left = 0
    }


debug : Element.Attribute Msg
debug =
    Element.explain Debug.todo


viewTitleInput : String -> Element Msg
viewTitleInput title =
    column [ spacing 10, width fill ]
        [ Input.text
            [ Font.bold
            ]
            { onChange = TitleChanged
            , text = title
            , placeholder = Just (Input.placeholder [] (el [] (text "Titel")))
            , label = Input.labelHidden "Titel"
            }
        , viewSingleValidationError title titleValidator
        ]


viewSingleValidationError : a -> Verify.Validator String a String -> Element Msg
viewSingleValidationError input theValidator =
    {--
      - TODO: give the uses a chance to type something before showing an error!
      --}
    case validateSingle input theValidator of
        Ok _ ->
            Element.none

        Err ( err, errs ) ->
            el [ Font.color Palette.red ] (text (err ++ Debug.toString errs))


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


viewInstructionsEditor : String -> Element Msg
viewInstructionsEditor initialValue =
    let
        options =
            """
        {
            "toolbar": ["bold", "italic", "strikethrough", "heading-1", "|", "unordered-list", "link", "|", "preview", "fullscreen", "|", "guide" ]
        }
        """
    in
    el [ height fill, width fill ]
        (Element.html
            (Html.node "easy-mde"
                [ Html.Attributes.id "instructions-editor"
                , Html.Attributes.attribute "placeholder" "Fyll i instruktioner..."
                , Html.Attributes.attribute "options" options
                , Html.Attributes.attribute "initialValue" initialValue
                ]
                []
            )
        )


viewIngredientsEditor : String -> Element Msg
viewIngredientsEditor initialValue =
    let
        options =
            """
        {
            "toolbar": ["bold", "italic", "heading-2", "|", "unordered-list", "|", "preview", "fullscreen", "|", "guide" ]
        }
        """
    in
    el [ height fill, width fill ]
        (Element.html
            (Html.node "easy-mde"
                [ Html.Attributes.id "ingredients-editor"
                , Html.Attributes.attribute "placeholder" "Fyll i en lista av ingredienser..."
                , Html.Attributes.attribute "options" options
                , Html.Attributes.attribute "initialValue" initialValue
                ]
                []
            )
        )


viewSaveButton : Element Msg
viewSaveButton =
    Input.button
        [ Background.color (rgb255 255 127 0), Border.rounded 3, padding 10, Font.color Palette.white ]
        { onPress = Just SubmitForm
        , label = text "Spara"
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
            case validator model.form of
                Ok verifiedForm ->
                    Debug.log "submitting"
                        ( model
                        , submitForm verifiedForm
                        )

                Err err ->
                    Debug.log ("error" ++ Debug.toString err)
                        ( model
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


submitForm : VerifiedForm -> Cmd Msg
submitForm verifiedForm =
    case toJson verifiedForm of
        Just jsonForm ->
            Task.succeed (SubmitValidForm jsonForm) |> Task.perform identity

        Nothing ->
            Cmd.none


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



{--
  - Validation
  --}


type alias VerifiedForm =
    { title : String
    , description : String
    , portions : Int
    , instructions : String
    , ingredients : String
    , tags : List String
    }


validator : Verify.Validator String RecipeForm VerifiedForm
validator =
    Verify.validate VerifiedForm
        |> Verify.verify .title titleValidator
        |> Verify.verify .description (String.Verify.notBlank "empty descr")
        |> Verify.keep .portions
        |> Verify.verify .instructions instructionsValidator
        |> Verify.keep .ingredients
        |> Verify.keep .tags


titleValidator : Verify.Validator String String String
titleValidator title =
    String.Verify.notBlank "Fyll i titeln på receptet, 🙏" title


instructionsValidator : Verify.Validator String String String
instructionsValidator instr =
    String.Verify.notBlank "Vänligen beskriv hur man tillagar detta recept ❤️" instr


ingredientsValidator : Verify.Validator String String String
ingredientsValidator ingredients =
    String.Verify.notBlank "Vänligen lista ingredienserna i detta recept 🙏" ingredients


validateSingle : a -> Verify.Validator String a String -> Result ( String, List String ) String
validateSingle value theValidator =
    (Verify.validate identity
        |> Verify.verify (\_ -> value) theValidator
    )
        value


toJson : VerifiedForm -> Maybe Encode.Value
toJson form =
    let
        portionsString recipe =
            String.fromInt recipe.portions

        maybeAddDescription description =
            case description of
                "" ->
                    []

                descr ->
                    [ ( "description", Encode.string descr ) ]
    in
    Just
        (Encode.object <|
            ([ ( "title", Encode.string form.title )
             , ( "instructions", Encode.string form.instructions )
             , ( "portions", Encode.string (portionsString form) )
             , ( "ingredients", Encode.string form.ingredients )
             , ( "tags", Encode.set Encode.string <| Set.fromList form.tags )
             ]
                ++ maybeAddDescription form.description
            )
        )
