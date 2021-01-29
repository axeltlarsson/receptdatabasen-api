module Page.Recipe.Form exposing (Model, Msg(..), fromRecipe, init, portMsg, toJson, update, uploadProgressMsg, view)

import Api
import Dict exposing (Dict)
import Element
    exposing
        ( Element
        , alignBottom
        , alignLeft
        , alignRight
        , alignTop
        , alpha
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
        , wrappedRow
        )
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import FeatherIcons
import File exposing (File)
import File.Select as Select
import Form exposing (errorBorder, onEnter, validateSingle, viewValidationError)
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Http
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
    , images : Dict Int UploadStatus
    , imagesValidationActive : Bool
    , tooManyFilesError : Bool
    , formValidationStatus : ValidationStatus
    }


type UploadStatus
    = UrlEncoding File
    | InProgress File Base64Url UploadProgress
    | Done (Maybe Base64Url) Url -- Nothing for Base64Url if fetched server (fromRecipe)


type alias UploadProgress =
    { sent : Int, size : Int }


type alias Url =
    String


type alias Base64Url =
    String


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
    , newTagInput = ""
    , tagValidationActive = False
    , images = Dict.empty
    , imagesValidationActive = False
    , tooManyFilesError = False
    , formValidationStatus = NotActivated
    }


fromRecipe : Recipe.Recipe Recipe.Full -> Model
fromRecipe recipe =
    let
        { id, title, description, images } =
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
            , images = List.indexedMap (\i { url, blurHash } -> ( i, Done Nothing url )) images |> Dict.fromList
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
        , viewImagesInput form.images form.tooManyFilesError
        , viewDescriptionInput form.descriptionValidationActive form.description
        , viewPortionsInput form.portions
        , el [ Font.size Palette.xLarge, Font.semiBold ] (text "Instruktioner")
        , viewInstructionsEditor form.instructionsValidationActive form.instructions
        , viewValidationError form.instructionsValidationActive form.instructions instructionsValidator
        , el [ Font.size Palette.xLarge, Font.semiBold ] (text "Ingredienser")
        , viewIngredientsEditor form.ingredientsValidationActive form.ingredients
        , viewValidationError form.ingredientsValidationActive form.ingredients ingredientsValidator
        , viewTagsInput form.tagValidationActive form.newTagInput form.tags
        , viewValidationError
            (form.imagesValidationActive
                && (case form.formValidationStatus of
                        Invalid ->
                            True

                        Valid ->
                            True

                        NotActivated ->
                            False
                   )
            )
            form.images
            imagesValidator
        , viewSaveButton form.formValidationStatus
        ]


edges =
    { top = 0
    , right = 0
    , bottom = 0
    , left = 0
    }


viewTitleInput : Bool -> String -> Element Msg
viewTitleInput validationActive title =
    column [ spacing 10, width fill ]
        [ Input.multiline
            ([ Font.size Palette.xxLarge
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
            , spellcheck = False
            }
        , viewValidationError validationActive title titleValidator
        ]


viewUploadProgress : { sent : Int, size : Int } -> Element Msg
viewUploadProgress ({ sent, size } as sending) =
    text <| (String.fromInt <| floor <| 100 * Http.fractionSent sending) ++ " %"


xIcon : Element Msg
xIcon =
    FeatherIcons.x |> FeatherIcons.toHtml [] |> Element.html


trashIcon : Element Msg
trashIcon =
    FeatherIcons.trash |> FeatherIcons.toHtml [] |> Element.html


uploadIcon : Element Msg
uploadIcon =
    FeatherIcons.upload |> FeatherIcons.toHtml [] |> Element.html


viewImagesInput : Dict Int UploadStatus -> Bool -> Element Msg
viewImagesInput imagesDict tooManyError =
    let
        rect =
            el
                [ Border.color Palette.lightGrey
                , Border.width 1
                , Border.rounded 2
                , width fill
                , height (Element.px 400)
                ]

        imageRect imageUrl =
            el
                [ width fill
                , height (Element.px 400)
                , Background.image imageUrl
                , Border.rounded 2
                ]

        uploadButton =
            Input.button
                [ centerX
                , centerY
                , padding 10
                , Background.color Palette.green
                , Border.rounded 2
                , Font.color Palette.white
                ]
                { onPress = Just ImagesUploadClicked
                , label =
                    row [] [ uploadIcon, text " Ladda upp bilder" ]
                }

        smallImage url idx =
            el
                [ Border.rounded 2
                , width (fill |> Element.minimum 150)
                , height (fill |> Element.maximum 300 |> Element.minimum 200)
                , Background.image url
                , Events.onClick (MakeMainImage idx)
                , Element.pointer
                , mouseOver [ Border.glow Palette.lightGrey 3 ]
                , Html.Attributes.title "Gör till huvudbild" |> Element.htmlAttribute
                ]

        removeButton attrs { label, idx } =
            el attrs
                (Input.button
                    [ Font.color Palette.white
                    , padding 10
                    , Html.Attributes.title "Ta bort bild" |> Element.htmlAttribute
                    ]
                    { onPress = Just (RemoveImage idx)
                    , label = label
                    }
                )
    in
    case Dict.toList imagesDict of
        [] ->
            column [ width fill, height fill ]
                [ rect uploadButton ]

        ( idx, mainImage ) :: moreImages ->
            column [ width fill, height fill, spacing 10 ]
                [ case mainImage of
                    UrlEncoding _ ->
                        uploadButton

                    InProgress _ base64Url progress ->
                        imageRect base64Url
                            (removeButton [ alignBottom, alignRight, padding 10 ]
                                { idx = idx
                                , label = row [ spacing 10 ] [ xIcon, viewUploadProgress progress ]
                                }
                            )

                    Done (Just base64Url) url ->
                        imageRect base64Url
                            (removeButton [ alignBottom, alignRight, padding 10 ]
                                { idx = idx
                                , label = row [] [ trashIcon ]
                                }
                            )

                    Done Nothing url ->
                        imageRect ("/images/sig/1600/" ++ url)
                            (removeButton [ alignBottom, alignRight, padding 10 ]
                                { idx = idx
                                , label = row [] [ trashIcon ]
                                }
                            )
                , wrappedRow [ height fill, width fill, spacing 10 ]
                    (moreImages
                        |> List.map
                            (\( i, image ) ->
                                case image of
                                    UrlEncoding _ ->
                                        smallImage "" i Element.none

                                    InProgress _ base64Url progress ->
                                        smallImage base64Url
                                            i
                                            (removeButton [ alignBottom, alignRight, padding 5 ]
                                                { idx = i
                                                , label = row [ spacing 10 ] [ xIcon, viewUploadProgress progress ]
                                                }
                                            )

                                    Done (Just base64Url) url ->
                                        smallImage base64Url
                                            i
                                            (removeButton [ alignBottom, alignRight, padding 5 ]
                                                { idx = i
                                                , label = row [] [ trashIcon ]
                                                }
                                            )

                                    Done Nothing url ->
                                        smallImage ("/images/sig/1600/" ++ url)
                                            i
                                            (removeButton [ alignBottom, alignRight, padding 5 ]
                                                { idx = i
                                                , label = row [] [ trashIcon ]
                                                }
                                            )
                            )
                    )
                , row [ alignLeft, spacing 10 ]
                    [ uploadButton
                    , if tooManyError then
                        el
                            [ padding 10
                            , Border.rounded 2
                            , Border.width 1
                            , Border.color Palette.lightGrey
                            , Font.color Palette.red
                            , Font.regular
                            , Events.onClick DismissTooManyFilesError
                            , Element.pointer
                            , Html.Attributes.title "Klicka för att avärda" |> Element.htmlAttribute
                            ]
                            (text "Max 5 bilder får lov att laddas upp! 🚨")

                      else
                        Element.none
                    ]
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
            "toolbar": ["bold", "italic", "strikethrough", "heading-1", "heading-2", "|", "unordered-list", "link", "|", "preview", "fullscreen", "|", "guide" ]
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
                , Html.Attributes.attribute "youtube" "true"
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
        [ row [ width (fill |> Element.maximum 400), spacing 10 ]
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
        , wrappedRow [ width fill, spacing 10 ]
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
        , mouseOver [ alpha 0.5 ]
        , Html.Attributes.title "Ta bort tagg" |> Element.htmlAttribute
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
            [ Background.color Palette.green, Border.rounded 2, padding 10, Font.color Palette.white ]
            { onPress = Just SubmitForm
            , label = text "Spara"
            }

    else
        Input.button
            [ Background.color Palette.grey, Border.rounded 2, padding 10, Font.color Palette.white ]
            { onPress = Nothing
            , label = text "Fyll i formuläret korrekt ⛔️"
            }



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
    | ImageUrlEncoded Int File Base64Url
    | ImageUploadComplete Int (Result Api.ServerError Recipe.ImageUrl)
    | RemoveImage Int
    | MakeMainImage Int
    | GotImageUploadProgress Int Http.Progress
    | ImagesUploadClicked
    | ImagesSelected File (List File)
    | DismissTooManyFilesError


portMsg : Decode.Value -> Msg
portMsg =
    PortMsgReceived


uploadProgressMsg : Int -> Http.Progress -> Msg
uploadProgressMsg =
    GotImageUploadProgress


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
            case model.form.formValidationStatus of
                Invalid ->
                    { newModel | form = { newForm | formValidationStatus = validity } }

                Valid ->
                    { newModel | form = { newForm | formValidationStatus = validity } }

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

        ImagesUploadClicked ->
            ( updateForm (\f -> { f | imagesValidationActive = True })
            , Select.files [ "image/jpeg", "image/png" ] ImagesSelected
            )

        ImagesSelected file moreFiles ->
            let
                idx =
                    -- The highest numbered key
                    Dict.foldl (\k v i -> max k i) 0 form.images + 1

                urlCmd i f =
                    Task.perform (ImageUrlEncoded i f) (File.toUrl f)

                cmds =
                    urlCmd idx file
                        :: List.indexedMap (\i f -> urlCmd (i + idx + 1) f) moreFiles

                newFilesDict =
                    (file :: moreFiles)
                        |> List.indexedMap (\i f -> ( i + idx, UrlEncoding f ))
                        |> Dict.fromList
            in
            if Dict.size form.images + List.length moreFiles + 1 > 5 then
                ( updateForm (\f -> { f | tooManyFilesError = True }), Cmd.none )

            else
                ( updateForm
                    (\f ->
                        { f
                            | images = Dict.union f.images newFilesDict
                            , imagesValidationActive = True
                            , tooManyFilesError = False
                        }
                    )
                , Cmd.batch cmds
                )

        ImageUrlEncoded idx file base64Url ->
            let
                updateImageDict =
                    Maybe.map
                        (\status ->
                            case status of
                                UrlEncoding f ->
                                    InProgress f base64Url { size = 100, sent = 0 }

                                x ->
                                    -- Should never happen: it would mean base64 encoding completes after server upload
                                    -- started, which is impossible as we don't upload until that is completed...
                                    -- TODO: handle debug
                                    -- Debug.log "ImageUrlEncoded while in wrong state"
                                    x
                        )
            in
            ( updateForm (\f -> { f | images = Dict.update idx updateImageDict f.images })
            , Recipe.uploadImage idx file (ImageUploadComplete idx)
            )

        GotImageUploadProgress idx progress ->
            case progress of
                Http.Sending sending ->
                    ( updateForm
                        (\f ->
                            { f
                                | images =
                                    Dict.update idx
                                        (Maybe.map
                                            (\image ->
                                                case image of
                                                    InProgress file base64Url _ ->
                                                        InProgress file base64Url sending

                                                    x ->
                                                        x
                                            )
                                        )
                                        f.images
                            }
                        )
                    , Cmd.none
                    )

                Http.Receiving _ ->
                    ( model, Cmd.none )

        ImageUploadComplete idx (Ok (Recipe.ImageUrl url)) ->
            let
                updateImageDict =
                    Maybe.map
                        (\p ->
                            case p of
                                InProgress file base64Url progress ->
                                    Done (Just base64Url) url

                                x ->
                                    -- TODO: handle debug
                                    -- Debug.log ("ImageUploadComplete while not being InProgress!" ++ Debug.toString x)
                                    -- Should never happen: it can't be done twice!
                                    x
                        )
            in
            ( updateForm (\f -> { f | images = Dict.update idx updateImageDict f.images })
            , Cmd.none
            )

        ImageUploadComplete base64Url (Err err) ->
            -- TODO: handle debug
            -- Debug.log (Debug.toString err)
            ( model, Cmd.none )

        RemoveImage idx ->
            ( updateForm (\f -> { f | images = Dict.remove idx f.images }), Http.cancel ("image" ++ String.fromInt idx) )

        MakeMainImage idx ->
            let
                swapWithMain : Int -> Dict Int a -> Dict Int a
                swapWithMain i dict =
                    let
                        newMain =
                            Dict.get i dict
                    in
                    case Dict.toList dict of
                        [] ->
                            -- Can't swap, empty dict
                            dict

                        ( k, oldMain ) :: _ ->
                            dict
                                |> Dict.update i (\_ -> Just oldMain)
                                |> Dict.update k (\_ -> newMain)
            in
            ( updateForm (\f -> { f | images = swapWithMain idx f.images }), Cmd.none )

        DismissTooManyFilesError ->
            ( updateForm (\f -> { f | tooManyFilesError = False }), Cmd.none )

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
                                , imagesValidationActive = True
                                , formValidationStatus = valid
                            }
                    }
            in
            case validator model.form of
                Ok verifiedForm ->
                    ( activatedModel Valid
                    , submitForm verifiedForm
                    )

                Err err ->
                    -- TODO: handle debug
                    -- Debug.log ("error" ++ Debug.toString err)
                    ( activatedModel Invalid
                    , Cmd.none
                    )

        SubmitValidForm _ ->
            -- Editor deals with this
            ( model, Cmd.none )

        PortMsgReceived m ->
            case Decode.decodeValue portMsgDecoder m of
                Err err ->
                    -- TODO: handle debug
                    -- Debug.log (Decode.errorToString err)
                    ( model, Cmd.none )

                Ok (InstructionsChange value) ->
                    ( updateForm (\f -> { f | instructions = value }), Cmd.none )

                Ok (IngredientsChange value) ->
                    ( updateForm (\f -> { f | ingredients = value }), Cmd.none )

                Ok IngredientsBlur ->
                    ( updateForm (\f -> { f | ingredientsValidationActive = True }), Cmd.none )

                Ok InstructionsBlur ->
                    ( updateForm (\f -> { f | instructionsValidationActive = True }), Cmd.none )

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
    , images : Dict Int UploadStatus
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
        |> Verify.verify .images imagesValidator


trim : Verify.Validator error String String
trim input =
    Ok (String.trim input)


imagesValidator : Verify.Validator String (Dict Int UploadStatus) (Dict Int UploadStatus)
imagesValidator input =
    let
        allDone =
            input
                |> Dict.values
                |> List.all
                    (\status ->
                        case status of
                            Done _ _ ->
                                True

                            _ ->
                                False
                    )
    in
    if allDone then
        Ok input

    else
        Verify.fail "Du måste vänta tills bilden laddats upp innan du kan spara ⌛️" input


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
        |> Verify.compose (String.Verify.maxLength 700 "Använd en kortare beskrivning 🙏")


ingredientsMarkdownValidator : Verify.Validator String String String
ingredientsMarkdownValidator input =
    if Markdown.onlyListAndHeading input then
        Ok input

    else
        Verify.fail "Skriv ingrediensera i en eller flera listor, eventuellt med rubriker emellan ❤️" input


instructionsMarkdownValidator : Verify.Validator String String String
instructionsMarkdownValidator input =
    Markdown.parsingErrors input
        |> Maybe.map (\e -> Verify.fail ("Det gick inte att parsa denna text korrekt, felet som uppstod var:\n" ++ e) input)
        |> Maybe.withDefault (Ok input)


instructionsValidator : Verify.Validator String String String
instructionsValidator =
    trim
        |> Verify.compose
            (String.Verify.notBlank "Vänligen beskriv hur man tillagar detta recept ❤️")
        |> Verify.compose
            (String.Verify.minLength 5 "Beskriv hur man tillagar detta recept med minst 5 tecken ☝")
        |> Verify.compose
            (String.Verify.maxLength 4000 "Skriv inte en hel roman här tack! ⛔️")
        |> Verify.compose
            instructionsMarkdownValidator


ingredientsValidator : Verify.Validator String String String
ingredientsValidator =
    trim
        |> Verify.compose
            (String.Verify.notBlank "Vänligen lista ingredienserna i detta recept 🙏")
        |> Verify.compose
            (String.Verify.minLength 3 "Vänligen inkludera minst en ingrediens, annars blir det svårt! 😉")
        |> Verify.compose
            (String.Verify.maxLength 4000 "Skriv inte en hel roman här tack! ⛔️")
        |> Verify.compose
            ingredientsMarkdownValidator


tagValidator : Verify.Validator String String String
tagValidator =
    trim
        |> Verify.compose
            (String.Verify.notBlank "Taggen får inte vara tom! ⚠️")
        |> Verify.compose
            (String.Verify.maxLength 32 "Taggar bör vara korta och koncisa! ⚡️")


toJson : VerifiedForm -> Maybe Encode.Value
toJson form =
    let
        maybeAddDescription description =
            case description of
                "" ->
                    [ ( "description", Encode.null ) ]

                descr ->
                    [ ( "description", Encode.string descr ) ]

        imagesEncoder : Dict Int UploadStatus -> Encode.Value
        imagesEncoder =
            Dict.map
                (\i imageStatus ->
                    case imageStatus of
                        Done _ url ->
                            Encode.object [ ( "url", Encode.string url ) ]

                        _ ->
                            -- imagesValidator will ensure this never happens
                            Encode.null
                )
                >> Dict.values
                >> Encode.list identity
    in
    Just
        (Encode.object <|
            ([ ( "title", Encode.string form.title )
             , ( "instructions", Encode.string form.instructions )
             , ( "portions", Encode.int form.portions )
             , ( "ingredients", Encode.string form.ingredients )
             , ( "tags", Encode.set Encode.string <| Set.fromList form.tags )
             , ( "images", imagesEncoder form.images )
             ]
                ++ maybeAddDescription form.description
            )
        )
