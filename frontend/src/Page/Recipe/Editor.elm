module Page.Recipe.Editor exposing (Model, Msg, initEdit, initNew, toSession, update, view)

import Array exposing (Array)
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (class, for, id, min, placeholder, style, type_, value)
import Html.Events exposing (keyCode, onInput, onSubmit, preventDefaultOn)
import Http exposing (Expect)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Recipe exposing (Full, Recipe, fetch, fullDecoder)
import Recipe.Slug as Slug exposing (Slug)
import Route
import Session exposing (Session(..))
import Set exposing (Set)
import Task
import Url.Builder
import Validate exposing (Valid, Validator, ifBlank, ifNotInt)



-- MODEL


type alias Model =
    { session : Session
    , status : Status
    }


type Status
    = -- New Recipe
      EditingNew (List Problem) Form
    | Creating Form
      -- Edit Recipe
    | Loading Slug
    | LoadingFailed Slug
    | Editing Slug (List Problem) Form
    | Saving Slug Form


type Problem
    = InvalidEntry ValidatedField String
    | ServerProblem String


type alias Form =
    { title : String
    , description : String
    , instructions : String
    , portions : Int
    , tags : Set String
    , newTagInput : String
    , newGroupInput : String
    , ingredients : Array ( GroupName, NewIngredientInput, Array String )
    }


type alias NewIngredientInput =
    String


type alias GroupName =
    String


initNew : Session -> ( Model, Cmd msg )
initNew session =
    ( { session = session
      , status =
            EditingNew []
                { title = ""
                , description = ""
                , instructions = ""
                , portions = 1
                , tags = Set.empty
                , newTagInput = ""
                , newGroupInput = ""
                , ingredients = Array.fromList [ ( "Ingredienser", "", Array.empty ) ]
                }
      }
    , Cmd.none
    )


initEdit : Session -> Slug -> ( Model, Cmd Msg )
initEdit session slug =
    ( { session = session
      , status = Loading slug
      }
    , Recipe.fetch slug (CompletedRecipeLoad slug)
    )



-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    { title = "Skapa nytt recept"
    , content =
        case model.status of
            -- Creating a new recipe
            EditingNew probs form ->
                div [] [ viewForm form probs, viewProblems probs ]

            Creating form ->
                viewForm form []

            -- Editing an existing recipe
            Loading slug ->
                text "Laddar..."

            LoadingFailed slug ->
                text ("Kunde ej ladda in recept: " ++ Slug.toString slug)

            Editing slug probs form ->
                div [] [ viewForm form probs, viewProblems probs ]

            Saving slug form ->
                viewForm form []
    }


viewForm : Form -> List Problem -> Html Msg
viewForm fields problems =
    form [ onSubmit ClickedSave ]
        [ viewTitleInput fields problems
        , viewDescriptionInput fields
        , viewPortionsInput fields
        , viewTagsInput fields
        , viewIngredientsInput fields
        , viewInstructionsInput fields problems
        , button []
            [ text "Spara" ]
        ]


viewTitleInput : Form -> List Problem -> Html Msg
viewTitleInput fields problems =
    div [ class "title" ]
        [ input
            [ placeholder "Namn på receptet..."
            , onInput ChangedTitle
            , value fields.title
            ]
            []
        , viewFieldErrors Title problems
        ]


viewDescriptionInput : Form -> Html Msg
viewDescriptionInput fields =
    div [ class "description" ]
        [ textarea
            [ placeholder "Beskrivning..."
            , onInput ChangedDescription
            , value fields.description
            ]
            []
        ]


viewPortionsInput : Form -> Html Msg
viewPortionsInput fields =
    div [ class "portions" ]
        [ label [ for "portions-input" ] [ text "Ange antal portioner" ]
        , input
            [ id "portions"
            , placeholder "Portioner"
            , type_ "number"
            , onInput ChangedPortions
            , value (String.fromInt fields.portions)
            , min "1"
            ]
            []
        ]


viewTagsInput : Form -> Html Msg
viewTagsInput fields =
    div [ class "tags" ]
        [ input
            [ placeholder "Ny tagg..."
            , onEnter PressedEnterTag
            , onInput (ChangedTag CurrentTag)
            , value fields.newTagInput
            ]
            []
        , ul []
            (List.map viewTag <| Set.toList fields.tags)
        ]


viewTag : String -> Html Msg
viewTag tag =
    li [] [ text tag ]


viewIngredientsInput : Form -> Html Msg
viewIngredientsInput fields =
    div [ class "ingredients" ]
        [ h2 [] [ text "Ingredienser" ]
        , div [] (List.map viewIngredientGroupInput <| Array.toIndexedList fields.ingredients)
        , input
            [ placeholder "Ny underrubrik..."
            , onEnter PressedEnterGroup
            , onInput (ChangedGroup NewGroupInput)
            , value fields.newGroupInput
            ]
            []
        ]


viewIngredientGroupInput : ( Int, ( String, NewIngredientInput, Array String ) ) -> Html Msg
viewIngredientGroupInput ( groupIdx, ( groupName, newIngredientInput, ingredients ) ) =
    let
        currentIngredients =
            List.map viewIngredient <| List.map (\t -> ( groupIdx, t )) <| Array.toIndexedList ingredients

        ingredientInput =
            input
                [ placeholder "Ny ingrediens..."
                , onEnter (PressedEnterIngredient groupIdx)
                , onInput (ChangedIngredient groupIdx CurrentIngredient)
                , value newIngredientInput
                ]
                []
    in
    div [ class "ingredient-group" ]
        [ input
            [ value groupName
            , onInput (ChangedGroup (GroupIndex groupIdx))
            ]
            []
        , ul [] (currentIngredients ++ [ ingredientInput ])
        ]


viewIngredient : ( Int, ( Int, String ) ) -> Html Msg
viewIngredient ( groupIdx, ( idx, ingredient ) ) =
    li []
        [ input
            [ value ingredient
            , onInput (ChangedIngredient groupIdx (IngredientIndex idx))
            ]
            []
        ]


viewInstructionsInput : Form -> List Problem -> Html Msg
viewInstructionsInput fields problems =
    div [ class "instructions" ]
        [ h3 [] [ text "Instruktioner" ]
        , textarea
            [ placeholder "Instruktioner..."
            , onInput ChangedInstructions
            , value fields.instructions
            ]
            []
        , viewFieldErrors Instructions problems
        ]


viewProblems : List Problem -> Html Msg
viewProblems problems =
    let
        serverProblem problem =
            case problem of
                ServerProblem _ ->
                    True

                _ ->
                    False
    in
    ul [ class "error-messages" ] (List.map viewProblem <| List.filter serverProblem problems)



{--
Filter list of problems to render only InvalidEntry for the given ValidatedField
That way you can call this function next to the each field,
e.g. `viewFieldErrors Title problems` next to the `title` input
and, `viewFieldErrors Description problems` next to the `description` input and so on.
--}


viewFieldErrors : ValidatedField -> List Problem -> Html Msg
viewFieldErrors field problems =
    let
        invalidEntry problem =
            case problem of
                InvalidEntry entry msg ->
                    entry == field

                ServerProblem msg ->
                    False

        invalidEntries =
            List.filter invalidEntry problems

        message problem =
            case problem of
                InvalidEntry entry msg ->
                    msg

                ServerProblem msg ->
                    msg
    in
    div [ class "invalid-entry" ]
        (List.map
            (\problem ->
                code [ style "background-color" "red", style "color" "white" ] [ text (message problem) ]
            )
            invalidEntries
        )


viewProblem : Problem -> Html msg
viewProblem problem =
    let
        errorMessage =
            case problem of
                InvalidEntry _ message ->
                    message

                ServerProblem message ->
                    message
    in
    li [] [ code [ style "background-color" "red", style "color" "white" ] [ text errorMessage ] ]


onEnter : Msg -> Attribute Msg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                Decode.succeed ( msg, True )

            else
                Decode.fail "not ENTER"
    in
    preventDefaultOn "keydown" (Decode.andThen isEnter keyCode)



-- UPDATE


type IngredientIndex
    = IngredientIndex Int
    | CurrentIngredient


type GroupIndex
    = GroupIndex Int
    | NewGroupInput


type TagIndex
    = TagIndex Int
    | CurrentTag


type Msg
    = ClickedSave
      -- Singular fields, we know which one has changed - because there is only one
    | ChangedTitle String
    | ChangedDescription String
    | ChangedInstructions String
    | ChangedPortions String
      -- Multiple inputs for each type of field - we need an index to determine which field in the model to update
    | ChangedTag TagIndex String
    | PressedEnterTag
    | ChangedIngredient Int IngredientIndex String
    | PressedEnterIngredient Int
    | ChangedGroup GroupIndex String
    | PressedEnterGroup
      -- Msg:s from the server
    | CompletedCreate (Result ServerError (Recipe Full))
    | CompletedRecipeLoad Slug (Result Http.Error (Recipe Full))
    | CompletedEdit (Result ServerError (Recipe Full))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedSave ->
            model.status
                |> save
                |> Tuple.mapFirst (\status -> { model | status = status })

        ChangedTitle title ->
            updateForm (\form -> { form | title = title }) model

        ChangedDescription description ->
            updateForm (\form -> { form | description = description }) model

        ChangedInstructions instructions ->
            updateForm (\form -> { form | instructions = instructions }) model

        ChangedPortions portions ->
            let
                portionsInt =
                    Maybe.withDefault 0 <| String.toInt portions
            in
            updateForm (\form -> { form | portions = portionsInt }) model

        ChangedTag CurrentTag tag ->
            updateForm (\form -> { form | newTagInput = tag }) model

        ChangedTag idx tag ->
            Debug.todo "Not yet implemented"

        PressedEnterTag ->
            updateForm
                (\form ->
                    { form
                        | tags = Set.insert form.newTagInput form.tags
                        , newTagInput = ""
                    }
                )
                model

        ChangedIngredient groupIdx CurrentIngredient ingredient ->
            let
                updateCurrentForGroup ( groupName, current, ingredients ) =
                    ( groupName, ingredient, ingredients )
            in
            updateForm
                (\form ->
                    { form | ingredients = updateIngredients form.ingredients groupIdx updateCurrentForGroup }
                )
                model

        ChangedIngredient groupIdx (IngredientIndex idx) ingredient ->
            let
                updateIngredientInGroup ( groupName, current, ingredients ) =
                    ( groupName, current, Array.set idx ingredient ingredients )
            in
            updateForm
                (\form ->
                    { form | ingredients = updateIngredients form.ingredients groupIdx updateIngredientInGroup }
                )
                model

        PressedEnterIngredient groupIdx ->
            let
                addIngredientToGroup ( groupName, current, ingredients ) =
                    ( groupName, "", Array.push current ingredients )
            in
            updateForm
                (\form ->
                    { form | ingredients = updateIngredients form.ingredients groupIdx addIngredientToGroup }
                )
                model

        ChangedGroup NewGroupInput group ->
            updateForm (\form -> { form | newGroupInput = group }) model

        ChangedGroup (GroupIndex groupIdx) newGroupName ->
            let
                changeGroupName ( groupName, current, ingredients ) =
                    ( newGroupName, current, ingredients )
            in
            updateForm (\form -> { form | ingredients = updateIngredients form.ingredients groupIdx changeGroupName }) model

        PressedEnterGroup ->
            updateForm (\form -> { form | newGroupInput = "", ingredients = Array.push ( form.newGroupInput, "", Array.empty ) form.ingredients })
                model

        -- Server events
        CompletedRecipeLoad _ (Ok recipe) ->
            let
                { id, title } =
                    Recipe.metadata recipe

                { description, instructions, tags, portions, ingredients } =
                    Recipe.contents recipe

                addCurrentInput ( groupName, ingredientList ) =
                    ( groupName, "", Array.fromList ingredientList )

                ingredientsArray =
                    Array.fromList (List.map addCurrentInput <| Dict.toList ingredients)

                status =
                    Editing (Recipe.slug recipe)
                        []
                        { title = Slug.toString title
                        , description = description
                        , instructions = instructions
                        , portions = portions
                        , tags = Set.fromList tags
                        , newTagInput = ""
                        , newGroupInput = ""
                        , ingredients = ingredientsArray
                        }
            in
            ( { model | status = status }, Cmd.none )

        CompletedRecipeLoad slug (Err error) ->
            ( { model | status = LoadingFailed slug }, Cmd.none )

        CompletedCreate (Ok recipe) ->
            ( { model | session = SessionWithRecipe recipe (Session.navKey model.session) }
            , Route.Recipe (Recipe.slug recipe)
                |> Route.replaceUrl (Session.navKey model.session)
            )

        CompletedCreate (Err error) ->
            ( { model | status = savingError error model.status }
            , Cmd.none
            )

        CompletedEdit (Ok recipe) ->
            ( { model | session = SessionWithRecipe recipe (Session.navKey model.session) }
            , Route.Recipe (Recipe.slug recipe)
                |> Route.replaceUrl (Session.navKey model.session)
            )

        CompletedEdit (Err error) ->
            ( { model | status = savingError error model.status }
            , Cmd.none
            )


type alias Group =
    ( String, String, Array String )


updateIngredients : Array Group -> Int -> (Group -> Group) -> Array Group
updateIngredients ingredients idx updateFun =
    let
        oldGroup =
            Array.get idx ingredients

        updated =
            case oldGroup of
                Just a ->
                    updateFun a

                Nothing ->
                    ( "", "", Array.empty )
    in
    Array.set idx updated ingredients


updateForm : (Form -> Form) -> Model -> ( Model, Cmd Msg )
updateForm transform model =
    let
        newModel =
            case model.status of
                Loading _ ->
                    model

                LoadingFailed _ ->
                    model

                Saving slug form ->
                    { model | status = Saving slug (transform form) }

                Editing slug errors form ->
                    { model | status = Editing slug errors (transform form) }

                EditingNew errors form ->
                    { model | status = EditingNew errors (transform form) }

                Creating form ->
                    { model | status = Creating (transform form) }
    in
    ( newModel, Cmd.none )


save : Status -> ( Status, Cmd Msg )
save status =
    case status of
        EditingNew _ form ->
            case Validate.validate formValidator (trimFields form) of
                Ok validForm ->
                    ( Creating form, create (Validate.fromValid validForm) )

                Err problems ->
                    ( EditingNew problems form, Cmd.none )

        Editing slug _ form ->
            case Validate.validate formValidator (trimFields form) of
                Ok validForm ->
                    ( Saving slug form, edit slug (Validate.fromValid validForm) )

                Err problems ->
                    ( Editing slug problems form, Cmd.none )

        _ ->
            ( status, Cmd.none )


savingError : ServerError -> Status -> Status
savingError error status =
    let
        problems =
            [ ServerProblem ("Error saving " ++ serverErrorToString error) ]
    in
    case status of
        Creating form ->
            EditingNew problems form

        Saving slug form ->
            Editing slug problems form

        _ ->
            status


serverErrorToString : ServerError -> String
serverErrorToString error =
    case error of
        ServerError (Http.BadUrl str) ->
            "BadUrl" ++ str

        ServerError Http.NetworkError ->
            "NetworkError"

        ServerErrorWithBody (Http.BadStatus status) body ->
            "BadStatus " ++ String.fromInt status ++ body

        ServerError (Http.BadBody str) ->
            "BadBody: " ++ str

        ServerError Http.Timeout ->
            "Timeout"

        _ ->
            ""


createUrl : String
createUrl =
    Url.Builder.crossOrigin "http://localhost:3000" [ "recipes" ] []


editUrl : Slug -> String
editUrl slug =
    Url.Builder.crossOrigin "http://localhost:3000"
        [ "recipes" ]
        [ Url.Builder.string "title" (String.concat [ "eq.", Slug.toString slug ]) ]


httpBodyFromForm : TrimmedForm -> Http.Body
httpBodyFromForm (Trimmed form) =
    let
        portionsString =
            String.fromInt form.portions

        ingredientTuple ( groupName, current, ingredients ) =
            -- TODO: add current to ingredients but filter out empty ingredients
            -- <| Array.filter (\x -> String.length x > 0) <| Array.push current
            -- this should be done somewhere...
            ( groupName, Array.toList ingredients )

        ingredientDict =
            Dict.fromList <| Array.toList <| Array.map ingredientTuple form.ingredients

        recipe =
            Encode.object
                [ ( "title", Encode.string form.title )
                , ( "description", Encode.string form.description )
                , ( "instructions", Encode.string form.instructions )
                , ( "portions", Encode.string portionsString )
                , ( "tags", Encode.set Encode.string form.tags )
                , ( "ingredients", Encode.dict identity (Encode.list Encode.string) ingredientDict )
                ]
    in
    Http.jsonBody recipe


edit : Slug -> TrimmedForm -> Cmd Msg
edit slug form =
    Http.request
        { url = editUrl slug
        , method = "PATCH"
        , timeout = Nothing
        , tracker = Nothing
        , headers =
            [ Http.header "Prefer" "return=representation"
            , Http.header "Accept" "application/vnd.pgrst.object+json"
            ]
        , body = httpBodyFromForm form
        , expect = expectJsonWithBody CompletedEdit Recipe.fullDecoder
        }


create : TrimmedForm -> Cmd Msg
create form =
    Http.request
        { url = createUrl
        , method = "POST"
        , timeout = Nothing
        , tracker = Nothing
        , headers =
            [ Http.header "Prefer" "return=representation"
            , Http.header "Accept" "application/vnd.pgrst.object+json"
            ]
        , body = httpBodyFromForm form
        , expect = expectJsonWithBody CompletedCreate Recipe.fullDecoder
        }


type ServerError
    = ServerError Http.Error
    | ServerErrorWithBody Http.Error String


expectJsonWithBody : (Result ServerError a -> Msg) -> Decoder a -> Expect Msg
expectJsonWithBody toMsg decoder =
    Http.expectStringResponse toMsg <|
        \response ->
            case response of
                Http.BadUrl_ urll ->
                    Err (ServerError (Http.BadUrl urll))

                Http.Timeout_ ->
                    Err (ServerError Http.Timeout)

                Http.NetworkError_ ->
                    Err (ServerError Http.NetworkError)

                Http.BadStatus_ metadata body ->
                    Err (ServerErrorWithBody (Http.BadStatus metadata.statusCode) body)

                Http.GoodStatus_ metadata body ->
                    case Decode.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err (ServerError (Http.BadBody (Decode.errorToString err)))


type TrimmedForm
    = Trimmed Form


trimFields : Form -> TrimmedForm
trimFields form =
    Trimmed
        { title = String.trim form.title
        , description = String.trim form.description
        , instructions = String.trim form.instructions
        , portions = form.portions
        , tags = Set.map String.trim form.tags
        , newTagInput = form.newTagInput
        , newGroupInput = form.newGroupInput
        , ingredients = form.ingredients
        }


type ValidatedField
    = Title
    | Instructions


formValidator : Validator Problem TrimmedForm
formValidator =
    Validate.all
        [ ifBlank (\(Trimmed f) -> f.title) (invalid Title "Titeln får ej vara tom")
        , ifBlank (\(Trimmed f) -> f.instructions) (invalid Instructions "Instruktioner måste anges")
        ]


invalid : ValidatedField -> String -> Problem
invalid field problem =
    InvalidEntry field problem


toSession : Model -> Session
toSession model =
    model.session
