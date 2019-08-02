module Page.Recipe.Editor exposing (Model, Msg, initNew, toSession, update, view)

import Browser exposing (Document)
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (class, for, id, min, placeholder, style, type_, value)
import Html.Events exposing (keyCode, onInput, onSubmit, preventDefaultOn)
import Http exposing (Expect)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Recipe exposing (Full, Recipe, fullDecoder)
import Recipe.Slug as Slug exposing (Slug)
import Route
import Session exposing (Session)
import Set exposing (Set)
import Url
import Url.Builder



-- MODEL


type alias Model =
    { session : Session
    , status : Status
    }


type Status
    = -- New Article
      EditingNew (List Problem) Form
    | Creating Form


type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type alias Form =
    { title : String
    , description : String
    , instructions : String
    , quantity : Int
    , tags : Set String
    , currentTag : String
    , currentIngredient : String
    , ingredients : List String
    }


initNew : Session -> ( Model, Cmd msg )
initNew session =
    ( { session = session
      , status =
            EditingNew []
                { title = ""
                , description = ""
                , instructions = ""
                , quantity = 1
                , tags = Set.empty
                , currentTag = ""
                , currentIngredient = ""
                , ingredients = []
                }
      }
    , Cmd.none
    )



-- VIEW


view : Model -> Document Msg
view model =
    { title = "New Recipe"
    , body =
        [ case model.status of
            EditingNew probs form ->
                div []
                    [ viewForm form
                    , viewProblems probs
                    ]

            Creating form ->
                viewForm form
        ]
    }


viewForm : Form -> Html Msg
viewForm fields =
    form [ onSubmit ClickedSave ]
        [ viewTitleInput fields
        , viewDescriptionInput fields
        , viewQuantityInput fields
        , viewTagsInput fields
        , viewIngredientsInput fields
        , viewInstructionsInput fields
        , button []
            [ text "Save" ]
        ]


viewInstructionsInput : Form -> Html Msg
viewInstructionsInput fields =
    div [ class "instructions" ]
        [ h3 [] [ text "Instructions" ]
        , textarea
            [ placeholder "Instruktioner"
            , onInput EnteredInstructions
            , value fields.instructions
            ]
            []
        ]


viewIngredientsInput : Form -> Html Msg
viewIngredientsInput fields =
    div [ class "ingredients" ]
        [ h3 [] [ text "Ingredients" ]
        , input
            [ placeholder "Ingredienser"
            , onEnter PressedEnterIngredient
            , onInput EnteredCurrentIngredient
            , value fields.currentIngredient
            ]
            []
        , ul [] (List.map viewIngredient fields.ingredients)
        ]


viewProblems : List Problem -> Html Msg
viewProblems problems =
    ul [ class "error-messages" ] (List.map viewProblem problems)


viewProblem : Problem -> Html msg
viewProblem problem =
    let
        errorMessage =
            case problem of
                InvalidEntry _ message ->
                    message

                ServerError message ->
                    message
    in
    li [] [ code [ style "background-color" "red", style "color" "white" ] [ text errorMessage ] ]


viewTagsInput : Form -> Html Msg
viewTagsInput fields =
    div [ class "tags" ]
        [ input
            [ placeholder "Tags"
            , onEnter PressedEnterTag
            , onInput EnteredCurrentTag
            , value fields.currentTag
            ]
            []
        , ul []
            (List.map viewTag <| Set.toList fields.tags)
        ]


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


viewTag : String -> Html Msg
viewTag tag =
    li [] [ text tag ]


viewIngredient : String -> Html Msg
viewIngredient ingredient =
    li [] [ text ingredient ]


viewDescriptionInput : Form -> Html Msg
viewDescriptionInput fields =
    div [ class "description" ]
        [ textarea
            [ placeholder "Description"
            , onInput EnteredDescription
            , value fields.description
            ]
            []
        ]


viewTitleInput : Form -> Html Msg
viewTitleInput fields =
    div [ class "title" ]
        [ input
            [ placeholder "Recipe Title"
            , onInput EnteredTitle
            , value fields.title
            ]
            []
        ]


viewQuantityInput : Form -> Html Msg
viewQuantityInput fields =
    div [ class "quantity" ]
        [ label [ for "quantity-input" ] [ text "Enter quantity" ]
        , input
            [ id "quantity"
            , placeholder "Quantity"
            , type_ "number"
            , onInput EnteredQuantity
            , value (String.fromInt fields.quantity)
            , min "1"
            ]
            []
        ]



-- UPDATE


type Msg
    = ClickedSave
    | EnteredTitle String
    | EnteredDescription String
    | EnteredInstructions String
    | EnteredQuantity String
    | EnteredCurrentTag String
    | EnteredCurrentIngredient String
    | PressedEnterTag
    | PressedEnterIngredient
    | CompletedCreate (Result MyError (Recipe Full))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedSave ->
            model.status
                |> save
                |> Tuple.mapFirst (\status -> { model | status = status })

        EnteredTitle title ->
            updateForm (\form -> { form | title = title }) model

        EnteredDescription description ->
            updateForm (\form -> { form | description = description }) model

        EnteredInstructions instructions ->
            updateForm (\form -> { form | instructions = instructions }) model

        EnteredQuantity quantity ->
            let
                quantityInt =
                    Maybe.withDefault 0 <| String.toInt quantity
            in
            updateForm (\form -> { form | quantity = quantityInt }) model

        EnteredCurrentTag currentTag ->
            updateForm (\form -> { form | currentTag = currentTag }) model

        PressedEnterTag ->
            updateForm
                (\form ->
                    { form
                        | tags = Set.insert form.currentTag form.tags
                        , currentTag = ""
                    }
                )
                model

        EnteredCurrentIngredient currentIngredient ->
            updateForm (\form -> { form | currentIngredient = currentIngredient }) model

        PressedEnterIngredient ->
            updateForm
                (\form ->
                    { form
                        | ingredients = form.currentIngredient :: form.ingredients
                        , currentIngredient = ""
                    }
                )
                model

        CompletedCreate (Ok recipe) ->
            ( model
            , Route.Recipe (Recipe.slug recipe)
                |> Route.replaceUrl (Session.navKey model.session)
            )

        CompletedCreate (Err error) ->
            ( { model | status = savingError error model.status }
            , Cmd.none
            )


save : Status -> ( Status, Cmd Msg )
save status =
    case status of
        EditingNew _ form ->
            ( Creating form, create form )

        _ ->
            ( status, Cmd.none )


savingError : MyError -> Status -> Status
savingError error status =
    let
        problems =
            [ ServerError ("Error saving " ++ myErrorAsString error) ]
    in
    case status of
        Creating form ->
            EditingNew problems form

        _ ->
            status


myErrorAsString : MyError -> String
myErrorAsString error =
    case error of
        MyError (Http.BadUrl str) ->
            "BadUrl" ++ str

        MyError Http.NetworkError ->
            "NetworkError"

        MyErrorWithBody (Http.BadStatus status) body ->
            "BadStatus " ++ String.fromInt status ++ body

        MyError (Http.BadBody str) ->
            "BadBody: " ++ str

        MyError Http.Timeout ->
            "Timeout"

        _ ->
            ""


url : String
url =
    Url.Builder.crossOrigin "http://localhost:3000" [ "recipes" ] []


create : Form -> Cmd Msg
create form =
    let
        quantityString =
            String.fromInt form.quantity

        ingredientDict =
            Dict.fromList [ ( "ingredients", form.ingredients ) ]

        recipe =
            Encode.object
                [ ( "title", Encode.string form.title )
                , ( "description", Encode.string form.description )
                , ( "instructions", Encode.string form.instructions )
                , ( "quantity", Encode.string quantityString )
                , ( "tags", Encode.set Encode.string form.tags )
                , ( "ingredients", Encode.dict identity (Encode.list Encode.string) ingredientDict )
                ]

        body =
            Http.jsonBody recipe
    in
    Http.request
        { url = url
        , method = "POST"
        , timeout = Nothing
        , tracker = Nothing
        , headers = [ Http.header "Prefer" "return=representation", Http.header "Accept" "application/vnd.pgrst.object+json" ]
        , body = body
        , expect = expectJson CompletedCreate Recipe.fullDecoder
        }


type MyError
    = MyError Http.Error
    | MyErrorWithBody Http.Error String


expectJson : (Result MyError a -> Msg) -> Decoder a -> Expect Msg
expectJson toMsg decoder =
    Http.expectStringResponse toMsg <|
        \response ->
            case response of
                Http.BadUrl_ urll ->
                    Err (MyError (Http.BadUrl urll))

                Http.Timeout_ ->
                    Err (MyError Http.Timeout)

                Http.NetworkError_ ->
                    Err (MyError Http.NetworkError)

                Http.BadStatus_ metadata body ->
                    Err (MyErrorWithBody (Http.BadStatus metadata.statusCode) body)

                Http.GoodStatus_ metadata body ->
                    case Decode.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            -- TODO: Http.BadBody is quite misleading - the decoding failed, not the request...
                            Err (MyError (Http.BadBody (Decode.errorToString err)))


updateForm : (Form -> Form) -> Model -> ( Model, Cmd Msg )
updateForm transform model =
    let
        newModel =
            case model.status of
                EditingNew errors form ->
                    { model | status = EditingNew errors (transform form) }

                Creating form ->
                    { model | status = Creating (transform form) }
    in
    ( newModel, Cmd.none )


type TrimmedForm
    = Trimmed Form


type ValidatedField
    = Title
    | Body


toSession : Model -> Session
toSession model =
    model.session
