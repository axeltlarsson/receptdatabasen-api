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


markup : String -> Delta
markup source =
    case Mark.compile document source of
        Mark.Success (Delta ops) ->
            Debug.log ("Mark.compile success " ++ Debug.toString ops ++ " | source: '" ++ Debug.toString source ++ "'")
                (Delta ops)

        Mark.Almost { result, errors } ->
            -- This is the case where there has been an error,
            -- but it has been caught by `Mark.onError` and is still rendereable.
            case result of
                Delta ops ->
                    Debug.log ("Mark.compile Almost errors: " ++ Debug.toString errors)
                        Delta
                        (List.append (deltaErrors errors) ops)

        -- , result
        Mark.Failure errors ->
            Debug.log ("Mark.compile failure: " ++ Debug.toString (List.map Mark.Error.toString errors))
                Delta
                (deltaErrors errors)


viewMarkup : Delta -> Element Msg
viewMarkup delta =
    let
        str =
            "|> Title\n    what? is this valid?"
    in
    case delta of
        Delta ops ->
            column [ spacing 10 ]
                [ row [] [ text "ops toString: ", el [ Border.width 1, Border.color Palette.black, padding 10 ] (text <| Debug.toString ops) ]

                -- , el [ padding 20, Border.width 1, Border.color Palette.black ] (text <| Debug.toString <| markup str)
                , row []
                    [ text "delta to string:"
                    , el [] (text <| Debug.toString delta)
                    ]
                ]


deltaErrors : List Mark.Error.Error -> List Op
deltaErrors errors =
    List.map
        (\e -> Insert (Mark.Error.toString e) [ Color "red" ])
        errors


type Delta
    = Delta (List Op)


type Op
    = Insert String (List Attribute)
    | Retain Int


type Attribute
    = Bold
    | Color String


document : Mark.Document Delta
document =
    Mark.document
        (\blocks -> Delta (List.concat blocks))
        (Mark.manyOf
            [ titleBlock
            , textBlock
            ]
        )


titleBlock : Mark.Block (List Op)
titleBlock =
    Mark.block "Title"
        (\str -> [ Insert ("|> Title\n    " ++ str) [ Bold ] ])
        Mark.string


textBlock : Mark.Block (List Op)
textBlock =
    Mark.textWith
        { view =
            \styles string ->
                Insert (string ++ "\n") []
        , replacements = Mark.commonReplacements
        , inlines = []
        }



{--
  - list : Mark.Block (Element Msg)
  - list =
  -     Mark.tree "List" renderList (Mark.map (row []) markText)
  -
  -
  -
  - -- Note: we have to define this as a separate function because
  - -- `Items` and `Node` are a pair of mutually recursive data structures.
  - -- It's easiest to render them using two separate functions:
  - -- renderList and renderItem
  -
  -
  - renderList : Mark.Enumerated (Element Msg) -> Element Msg
  - renderList (Mark.Enumerated enum) =
  -     let
  -         group =
  -             case enum.icon of
  -                 Mark.Bullet ->
  -                     Font.color Palette.grey
  -
  -                 Mark.Number ->
  -                     Font.color Palette.red
  -     in
  -     column [ group ]
  -         (List.map renderItem enum.items)
  -
  -
  - renderItem : Mark.Item (Element Msg) -> Element Msg
  - renderItem (Mark.Item item) =
  -     column [ padding 30 ]
  -         [ row [] item.content
  -         , renderList item.children
  -         ]
  -
  -
  --}


viewQuill : Html Msg
viewQuill =
    Html.node "quill-editor"
        [ Html.Attributes.attribute "content" ""
        , Html.Attributes.attribute "format" "html"
        , Html.Attributes.attribute "theme" "snow"
        , Html.Attributes.attribute "bounds" "#quill-editor"
        , Html.Attributes.attribute "id" "quill-editor"
        , Html.Attributes.attribute "modules" "{\"elm-port\": true}"
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
    , delta : Delta
    }


init : ( Model, Cmd Msg )
init =
    ( { form = initialForm, delta = Delta [] }, Cmd.none )


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
    , delta = Delta []
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
view { form, delta } =
    column [ Region.mainContent, width fill ]
        [ viewMarkup delta
        , viewForm form
        ]


viewForm : RecipeForm -> Element Msg
viewForm form =
    column [ width fill, spacing 30, padding 10, Font.extraLight ]
        [ el [ height <| Element.px 200 ] (Element.html viewQuill)
        , column [ width (fill |> Element.maximum 700), centerX, spacing 30 ]
            [ viewTitleInput form.title
            , viewDescriptionInput form.description
            , viewPortionsInput form.portions
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
    | QuillMsgReceived Decode.Value
    | SendQuillMsg Encode.Value


portMsg : Decode.Value -> Msg
portMsg =
    QuillMsgReceived


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

        QuillMsgReceived x ->
            let
                res =
                    case Decode.decodeValue quillDecoder x of
                        Err err ->
                            Debug.log (Decode.errorToString err)
                                Cmd.none

                        Ok y ->
                            -- Drop the newline at the end
                            let
                                text =
                                    String.dropRight 1 y.text

                                isSpaceInsert =
                                    case y.delta of
                                        Delta (z :: [ Insert " " [] ]) ->
                                            True

                                        _ ->
                                            False
                            in
                            Debug.log (text ++ " | " ++ Debug.toString y.delta ++ " isSpaceInsert: " ++ Debug.toString isSpaceInsert)
                                (if not isSpaceInsert then
                                    Task.succeed
                                        (SendQuillMsg (deltaEncoder <| markup y.text))
                                        |> Task.perform identity

                                 else
                                    Cmd.none
                                )
            in
            Debug.log "result: "
                ( model
                , res
                )

        SendQuillMsg x ->
            -- Editor deals with this
            ( model, Cmd.none )


type alias TextChange =
    { delta : Delta, text : String }


quillDecoder : Decode.Decoder TextChange
quillDecoder =
    Decode.map2 TextChange
        (Decode.field "delta" deltaDecoder)
        (Decode.field "text" Decode.string)


deltaDecoder : Decode.Decoder Delta
deltaDecoder =
    Decode.map Delta (Decode.field "ops" (Decode.list (Decode.lazy (\_ -> opDecoder))))


opDecoder : Decode.Decoder Op
opDecoder =
    Decode.oneOf
        [ retainDecoder
        , insertDecoder
        ]


insertDecoder : Decode.Decoder Op
insertDecoder =
    Decode.field "insert"
        (Decode.map2 Insert
            Decode.string
            (Decode.succeed [])
        )


retainDecoder : Decode.Decoder Op
retainDecoder =
    Decode.field "retain"
        (Decode.map Retain
            Decode.int
        )



{--
  - type Delta
  -     = Delta (List Op)
  -
  --}
{--
  - type Op
  -     = Insert String (List Attribute)
  -
  -
  - type Attribute
  -     = Bold
  -     | Color String
  --}


deltaEncoder : Delta -> Encode.Value
deltaEncoder (Delta ops) =
    Encode.object
        [ ( "ops"
          , Encode.list opEncoder (List.append ops [ Insert "\n" [] ])
          )
        ]


opEncoder : Op -> Encode.Value
opEncoder op =
    case op of
        Insert str attributes ->
            Encode.object
                [ ( "insert", Encode.string str )
                , ( "attributes", Encode.object (List.map attributeEncoder attributes) )
                ]

        Retain int ->
            Encode.object [ ( "retain", Encode.int int ) ]


attributeEncoder : Attribute -> ( String, Encode.Value )
attributeEncoder attribute =
    case attribute of
        Color color ->
            ( "color", Encode.string color )

        Bold ->
            ( "bold", Encode.bool True )


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
