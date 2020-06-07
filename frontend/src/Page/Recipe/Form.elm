module Page.Recipe.Form exposing (Model, Msg(..), fromRecipe, init, portMsg, toJson, update, view)

import Dict exposing (Dict)
import Element exposing (Element, alignBottom, alignLeft, alignRight, alignTop, centerX, centerY, column, el, fill, height, padding, paddingEach, paragraph, rgb255, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
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
    , titleValidationActive : Bool
    , description : String
    , descriptionValidationActive : Bool
    , portions : Int
    , instructions : String
    , instructionsValidationActive : Bool
    , ingredients : String
    , ingredientsValidationActive : Bool
    , tags : List String
    , validationStatus : ValidationStatus -- TODO: is this the way?

    -- , newTagInput : String
    }


type ValidationStatus
    = NotActivated
    | Invalid
    | Valid


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
    , titleValidationActive = False
    , description = ""
    , descriptionValidationActive = False
    , portions = 4
    , instructions = ""
    , instructionsValidationActive = False
    , ingredients = ""
    , ingredientsValidationActive = False
    , tags = []
    , validationStatus = NotActivated
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
        , titleValidationActive = False
        , description = Maybe.withDefault "" description
        , descriptionValidationActive = False
        , portions = portions
        , instructions = instructions
        , instructionsValidationActive = False
        , ingredients = ingredients
        , ingredientsValidationActive = False
        , tags = tags
        , validationStatus = NotActivated
        }
    }


view : Model -> Element Msg
view { form } =
    column [ Region.mainContent, width fill ]
        [ viewForm form
        ]


viewForm : RecipeForm -> Element Msg
viewForm form =
    column [ width (fill |> Element.maximum 700), centerX, spacing 20, padding 10, Font.extraLight ]
        [ viewTitleInput form.titleValidationActive form.title
        , viewDescriptionInput form.descriptionValidationActive form.description
        , viewPortionsInput form.portions
        , el [ Font.size 36, Font.semiBold ] (text "Gör så här")
        , viewInstructionsEditor form.instructions
        , viewSingleValidationError form.instructionsValidationActive form.instructions instructionsValidator
        , el [ Font.size 36, Font.semiBold ] (text "Ingredienser")
        , viewIngredientsEditor form.ingredients
        , viewSingleValidationError form.ingredientsValidationActive form.ingredients ingredientsValidator
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


viewTitleInput : Bool -> String -> Element Msg
viewTitleInput validationActive title =
    column [ spacing 10, width fill ]
        [ Input.text
            [ Font.bold
            , Events.onLoseFocus BlurredTitle
            ]
            { onChange = TitleChanged
            , text = title
            , placeholder = Just (Input.placeholder [] (el [] (text "Titel")))
            , label = Input.labelHidden "Titel"
            }
        , viewSingleValidationError validationActive title titleValidator
        ]


viewSingleValidationError : Bool -> a -> Verify.Validator String a String -> Element Msg
viewSingleValidationError active input theValidator =
    if active then
        case validateSingle input theValidator of
            Ok _ ->
                Element.none

            Err ( err, errs ) ->
                el [ Font.color Palette.red ] (text err)

    else
        Element.none


viewDescriptionInput : Bool -> String -> Element Msg
viewDescriptionInput validationActive description =
    column [ width fill, spacing 10, Events.onLoseFocus BlurredDescription ]
        [ Input.multiline
            [ height (fill |> Element.minimum 120 |> Element.maximum 240) ]
            { onChange = DescriptionChanged
            , text = description
            , placeholder = Just (Input.placeholder [] (el [] (text "Beskriv receptet med en trevlig introduktion...")))
            , label = Input.labelHidden "Beskrivning"
            , spellcheck = True
            }
        , viewSingleValidationError validationActive description descriptionValidator
        ]


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
        , min = 1
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
    | BlurredTitle
    | BlurredDescription


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

        BlurredTitle ->
            ( { model | form = { form | titleValidationActive = True } }, Cmd.none )

        BlurredDescription ->
            ( { model | form = { form | descriptionValidationActive = True } }, Cmd.none )

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
            let
                activatedModel =
                    { model
                        | form =
                            { form
                                | titleValidationActive = True
                                , descriptionValidationActive = True
                                , instructionsValidationActive = True
                                , ingredientsValidationActive = True
                            }
                    }
            in
            case validator model.form of
                Ok verifiedForm ->
                    Debug.log "submitting"
                        ( activatedModel
                        , submitForm verifiedForm
                        )

                Err err ->
                    Debug.log ("error" ++ Debug.toString err)
                        ( activatedModel
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

                Ok IngredientsBlur ->
                    ( { model | form = { form | ingredientsValidationActive = True } }, Cmd.none )

                Ok InstructionsBlur ->
                    ( { model | form = { form | instructionsValidationActive = True } }, Cmd.none )

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
    | IngredientsBlur
    | InstructionsBlur


portMsgDecoder : Decode.Decoder PortMsg
portMsgDecoder =
    Decode.field "type" Decode.string |> Decode.andThen typeDecoder


typeDecoder : String -> Decode.Decoder PortMsg
typeDecoder t =
    case t of
        "change" ->
            Decode.field "id" Decode.string |> Decode.andThen changeDecoder

        "blur" ->
            Decode.field "id" Decode.string |> Decode.andThen blurDecoder

        _ ->
            Decode.fail ("trying to decode port message, but " ++ t ++ "is not supported")


blurDecoder : String -> Decode.Decoder PortMsg
blurDecoder id =
    case id of
        "ingredients-editor" ->
            Decode.succeed IngredientsBlur

        "instructions-editor" ->
            Decode.succeed InstructionsBlur

        _ ->
            Decode.fail ("trying to decode blur message, but " ++ id ++ " is not supported")


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
        |> Verify.verify .description descriptionValidator
        |> Verify.keep .portions
        |> Verify.verify .instructions instructionsValidator
        |> Verify.verify .ingredients ingredientsValidator
        |> Verify.keep .tags


trim : Verify.Validator error String String
trim input =
    Ok (String.trim input)


titleValidator : Verify.Validator String String String
titleValidator =
    trim
        |> Verify.compose
            (String.Verify.notBlank "Fyll i titeln på receptet 🙏")
        |> Verify.compose
            (String.Verify.minLength 3 "Titeln måste vara minst 3 tecken lång 👮\u{200D}♀️")
        |> Verify.compose (String.Verify.maxLength 100 "Titlen får max innehålla 100 tecken 🚫")


descriptionValidator : Verify.Validator String String String
descriptionValidator =
    trim
        |> Verify.compose (String.Verify.maxLength 500 "Använd en kortare beskrivning 🙏")


instructionsValidator : Verify.Validator String String String
instructionsValidator =
    trim
        |> Verify.compose
            (String.Verify.notBlank "Vänligen beskriv hur man tillagar detta recept ❤️")
        |> Verify.compose
            (String.Verify.minLength 5 "Beskriv hur man tillagar detta recept med minst 5 tecken ☝")
        |> Verify.compose
            (String.Verify.maxLength 4000 "Skriv inte en hel novell här tack! ⛔️")


ingredientsValidator : Verify.Validator String String String
ingredientsValidator =
    trim
        |> Verify.compose
            (String.Verify.notBlank "Vänligen lista ingredienserna i detta recept 🙏")
        |> Verify.compose
            (String.Verify.minLength 3 "Vänligen inkludera minst en ingrediens, annars blir det svårt! 😉")
        |> Verify.compose
            (String.Verify.maxLength 4000 "Skriv inte en hel novell här tack! ⛔️")


validateSingle : a -> Verify.Validator String a String -> Result ( String, List String ) String
validateSingle value theValidator =
    (Verify.validate identity
        |> Verify.verify (\_ -> value) theValidator
    )
        value


toJson : VerifiedForm -> Maybe Encode.Value
toJson form =
    let
        maybeAddDescription description =
            case description of
                "" ->
                    [ ( "description", Encode.null ) ]

                descr ->
                    [ ( "description", Encode.string descr ) ]
    in
    Just
        (Encode.object <|
            ([ ( "title", Encode.string form.title )
             , ( "instructions", Encode.string form.instructions )
             , ( "portions", Encode.int form.portions )
             , ( "ingredients", Encode.string form.ingredients )
             , ( "tags", Encode.set Encode.string <| Set.fromList form.tags )
             ]
                ++ maybeAddDescription form.description
            )
        )
