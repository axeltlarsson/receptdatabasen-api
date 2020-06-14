module Page.Recipe.Form exposing (Model, Msg(..), fromRecipe, init, portMsg, toJson, update, view)

import Dict exposing (Dict)
import Element
    exposing
        ( Element
        , alignBottom
        , alignLeft
        , alignRight
        , alignTop
        , centerX
        , centerY
        , column
        , el
        , fill
        , height
        , mouseOver
        , padding
        , paddingEach
        , paragraph
        , rgb255
        , row
        , spacing
        , text
        , width
        )
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import FeatherIcons
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode
import Page.Recipe.Markdown as Markdown
import Palette
import Recipe
import Recipe.Slug as Slug
import Regex
import Set exposing (Set)
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
    , newTagInput : String
    , tagValidationActive : Bool
    , validationStatus : ValidationStatus -- TODO: rename to something that is more tied to its single use for the save button?
    }


type ValidationStatus
    = NotActivated
    | Invalid
    | Valid


type alias Model =
    { form : RecipeForm
    , markdownPreview : Element Msg
    }


init : ( Model, Cmd Msg )
init =
    ( { form = initialForm
      , markdownPreview = Element.none
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
    , newTagInput = ""
    , tagValidationActive = False
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
        { initialForm
            | title = Slug.toString title
            , description = Maybe.withDefault "" description
            , portions = portions
            , instructions = instructions
            , ingredients = ingredients
            , tags = tags
        }
    , markdownPreview = Element.none
    }


view : Model -> Element Msg
view { form, markdownPreview } =
    column [ Region.mainContent, width fill ]
        [ viewForm form
        , el
            [ Element.htmlAttribute (Html.Attributes.style "visibility" "hidden")
            , Element.htmlAttribute (Html.Attributes.class "markdown-preview")
            ]
            markdownPreview
        ]


viewForm : RecipeForm -> Element Msg
viewForm form =
    column [ width (fill |> Element.maximum 700), centerX, spacing 20, padding 10, Font.extraLight ]
        [ viewTitleInput form.titleValidationActive form.title
        , viewDescriptionInput form.descriptionValidationActive form.description
        , viewPortionsInput form.portions
        , el [ Font.size 36, Font.semiBold ] (text "Instruktioner")
        , viewInstructionsEditor form.instructionsValidationActive form.instructions
        , viewValidationError form.instructionsValidationActive form.instructions instructionsValidator
        , el [ Font.size 36, Font.semiBold ] (text "Ingredienser")
        , viewIngredientsEditor form.ingredientsValidationActive form.ingredients
        , viewValidationError form.ingredientsValidationActive form.ingredients ingredientsValidator
        , viewTagsInput form.tagValidationActive form.newTagInput form.tags
        , viewSaveButton form.validationStatus
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


errorBorder : Bool -> a -> Verify.Validator String a String -> List (Element.Attribute Msg)
errorBorder active input theValidator =
    let
        fieldIsInvalid =
            case validateSingle input theValidator of
                Ok _ ->
                    False

                Err _ ->
                    True
    in
    if active && fieldIsInvalid then
        [ Border.width 1
        , Border.rounded 2
        , Border.color Palette.red
        ]

    else
        []


viewValidationError : Bool -> a -> Verify.Validator String a String -> Element Msg
viewValidationError active input theValidator =
    if active then
        case validateSingle input theValidator of
            Ok _ ->
                Element.none

            Err ( err, errs ) ->
                el
                    [ Font.color Palette.red ]
                    (text err)

    else
        Element.none


viewTitleInput : Bool -> String -> Element Msg
viewTitleInput validationActive title =
    column [ spacing 10, width fill ]
        [ Input.text
            ([ Font.size 44
             , Font.semiBold
             , Border.rounded 2
             , Events.onLoseFocus BlurredTitle
             ]
                ++ errorBorder validationActive title titleValidator
            )
            { onChange = TitleChanged
            , text = title
            , placeholder = Just (Input.placeholder [] (el [] (text "Titel")))
            , label = Input.labelHidden "Titel"
            }
        , viewValidationError validationActive title titleValidator
        ]


viewDescriptionInput : Bool -> String -> Element Msg
viewDescriptionInput validationActive description =
    column [ width fill, spacing 10 ]
        [ Input.multiline
            ([ height (fill |> Element.minimum 120 |> Element.maximum 240)
             , Border.rounded 2
             , Events.onLoseFocus BlurredDescription
             ]
                ++ errorBorder validationActive description descriptionValidator
            )
            { onChange = DescriptionChanged
            , text = description
            , placeholder = Just (Input.placeholder [] (el [] (text "Beskriv receptet med en trevlig introduktion...")))
            , label = Input.labelHidden "Beskrivning"
            , spellcheck = True
            }
        , viewValidationError validationActive description descriptionValidator
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


viewInstructionsEditor : Bool -> String -> Element Msg
viewInstructionsEditor validationActive instructions =
    let
        options =
            """
        {
            "toolbar": ["bold", "italic", "strikethrough", "heading-1", "|", "unordered-list", "link", "|", "preview", "fullscreen", "|", "guide" ]
        }
        """
    in
    el ([ height fill, width fill ] ++ errorBorder validationActive instructions instructionsValidator)
        (Element.html
            (Html.node "easy-mde"
                [ Html.Attributes.id "instructions-editor"
                , Html.Attributes.attribute "placeholder" "Fyll i instruktioner..."
                , Html.Attributes.attribute "options" options
                , Html.Attributes.attribute "initialValue" instructions
                ]
                []
            )
        )


viewIngredientsEditor : Bool -> String -> Element Msg
viewIngredientsEditor validationActive ingredients =
    let
        options =
            """
        {
            "toolbar": ["bold", "italic", "heading-2", "|", "unordered-list", "|", "preview", "fullscreen", "|", "guide" ]
        }
        """
    in
    el ([ height fill, width fill ] ++ errorBorder validationActive ingredients ingredientsValidator)
        (Element.html
            (Html.node "easy-mde"
                [ Html.Attributes.id "ingredients-editor"
                , Html.Attributes.attribute "placeholder" "Fyll i en lista av ingredienser..."
                , Html.Attributes.attribute "options" options
                , Html.Attributes.attribute "initialValue" ingredients
                ]
                []
            )
        )


viewTagsInput : Bool -> String -> List String -> Element Msg
viewTagsInput validationActive newTag tags =
    let
        plusIcon =
            FeatherIcons.plus |> FeatherIcons.toHtml [] |> Element.html
    in
    column [ width fill, spacing 10 ]
        [ row [ width fill, spacing 10 ]
            [ Input.text [ Element.htmlAttribute (onEnter NewTagEntered), Border.rounded 2 ]
                { onChange = NewTagInputChanged
                , text = newTag
                , placeholder = Just (Input.placeholder [] (text "Ny tagg"))
                , label = Input.labelHidden "Taggar"
                }
            , Input.button
                [ Background.color Palette.green
                , padding 10
                , height fill
                , Border.rounded 2
                , Font.color Palette.white
                ]
                { onPress = Just NewTagEntered, label = plusIcon }
            ]
        , viewValidationError validationActive newTag tagValidator
        , row [ width fill, spacing 10 ]
            (List.map viewTag tags)
        ]


viewTag : String -> Element Msg
viewTag tag =
    el
        [ Background.color Palette.grey
        , Font.color Palette.white
        , Border.rounded 2
        , padding 10
        , Events.onClick (RemoveTag tag)
        , mouseOver [ Element.alpha 0.5 ]
        , Element.pointer
        ]
        (text tag)


viewSaveButton : ValidationStatus -> Element Msg
viewSaveButton status =
    let
        activeButton =
            case status of
                Invalid ->
                    False

                _ ->
                    True
    in
    if activeButton then
        Input.button
            [ Background.color Palette.green, Border.rounded 3, padding 10, Font.color Palette.white ]
            { onPress = Just SubmitForm
            , label = text "Spara"
            }

    else
        Input.button
            [ Background.color Palette.grey, Border.rounded 3, padding 10, Font.color Palette.white ]
            { onPress = Nothing
            , label = text "Fyll i formuläret korrekt ⛔️"
            }


onEnter : msg -> Html.Attribute msg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                Decode.succeed ( msg, True )

            else
                Decode.fail "not ENTER"
    in
    Html.Events.preventDefaultOn "keydown" (Decode.andThen isEnter Html.Events.keyCode)



-- UPDATE


type Msg
    = TitleChanged String
    | DescriptionChanged String
    | PortionsChanged Int
    | InstructionsChanged String
    | IngredientsChanged String
    | NewTagInputChanged String
    | NewTagEntered
    | RemoveTag String
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
    let
        updateForm : (RecipeForm -> RecipeForm) -> Model
        updateForm f =
            let
                newModel =
                    { model | form = f model.form }

                newForm =
                    newModel.form

                validity =
                    case validator newModel.form of
                        Ok _ ->
                            Valid

                        Err _ ->
                            Invalid
            in
            case model.form.validationStatus of
                Invalid ->
                    { newModel | form = { newForm | validationStatus = validity } }

                Valid ->
                    { newModel | form = { newForm | validationStatus = validity } }

                NotActivated ->
                    { newModel | form = newForm }
    in
    case msg of
        TitleChanged title ->
            ( updateForm (\f -> { f | title = title })
            , Cmd.none
            )

        BlurredTitle ->
            ( updateForm (\f -> { f | titleValidationActive = True })
            , Cmd.none
            )

        BlurredDescription ->
            ( updateForm (\f -> { f | descriptionValidationActive = True })
            , Cmd.none
            )

        DescriptionChanged description ->
            ( updateForm (\f -> { f | description = description })
            , Cmd.none
            )

        PortionsChanged portions ->
            ( updateForm (\f -> { f | portions = portions })
            , Cmd.none
            )

        InstructionsChanged instructions ->
            ( updateForm (\f -> { f | instructions = instructions })
            , Cmd.none
            )

        IngredientsChanged ingredients ->
            ( updateForm (\f -> { f | ingredients = ingredients })
            , Cmd.none
            )

        NewTagInputChanged newTag ->
            ( updateForm (\f -> { f | newTagInput = newTag })
            , Cmd.none
            )

        NewTagEntered ->
            ( updateForm
                (\f ->
                    case validateSingle f.newTagInput tagValidator of
                        Ok _ ->
                            { f | newTagInput = "", tags = List.append f.tags [ f.newTagInput ], tagValidationActive = False }

                        Err _ ->
                            { f | tagValidationActive = True }
                )
            , Cmd.none
            )

        RemoveTag tag ->
            ( updateForm (\f -> { f | tags = List.filter (\t -> t /= tag) f.tags }), Cmd.none )

        SubmitForm ->
            let
                activatedModel valid =
                    { model
                        | form =
                            { form
                                | titleValidationActive = True
                                , descriptionValidationActive = True
                                , instructionsValidationActive = True
                                , ingredientsValidationActive = True
                                , validationStatus = valid
                            }
                    }
            in
            case validator model.form of
                Ok verifiedForm ->
                    ( activatedModel Valid
                    , submitForm verifiedForm
                    )

                Err err ->
                    Debug.log ("error" ++ Debug.toString err)
                        ( activatedModel Invalid
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
                    ( updateForm (\f -> { f | instructions = value }), Cmd.none )

                Ok (IngredientsChange value) ->
                    ( updateForm (\f -> { f | ingredients = value }), Cmd.none )

                Ok IngredientsBlur ->
                    ( updateForm (\f -> { f | ingredientsValidationActive = True }), Cmd.none )

                Ok InstructionsBlur ->
                    ( updateForm (\f -> { f | instructionsValidationActive = True }), Cmd.none )

                Ok (PreviewMarkdown raw) ->
                    let
                        result =
                            -- BlurredTitle is only used as a Dummy
                            case Markdown.render raw Dict.empty (\x y -> BlurredTitle) of
                                Ok md ->
                                    column [] md

                                Err err ->
                                    text err
                    in
                    Debug.log "storing some secret markdown on the page"
                        ( { model | markdownPreview = result }, Cmd.none )

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
    | PreviewMarkdown String


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

        "previewMarkdown" ->
            previewMarkdownDecoder

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


previewMarkdownDecoder : Decode.Decoder PortMsg
previewMarkdownDecoder =
    Decode.map PreviewMarkdown (Decode.field "value" Decode.string)



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
        -- Verification of tags on input
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
            (String.Verify.maxLength 4000 "Skriv inte en hel roman här tack! ⛔️")


ingredientsValidator : Verify.Validator String String String
ingredientsValidator =
    trim
        |> Verify.compose
            (String.Verify.notBlank "Vänligen lista ingredienserna i detta recept 🙏")
        |> Verify.compose
            (String.Verify.minLength 3 "Vänligen inkludera minst en ingrediens, annars blir det svårt! 😉")
        |> Verify.compose
            (String.Verify.maxLength 4000 "Skriv inte en hel roman här tack! ⛔️")


tagValidator : Verify.Validator String String String
tagValidator =
    trim
        |> Verify.compose
            (String.Verify.notBlank "Taggen får inte vara tom! ⚠️")
        |> Verify.compose
            (String.Verify.maxLength 32 "Taggar bör vara korta och koncisa! ⚡️")


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
