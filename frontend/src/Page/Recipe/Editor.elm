module Page.Recipe.Editor exposing (Model, Msg, initEdit, initNew, toSession, update, view)

import Array exposing (Array)
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Form exposing (Form)
import Form.View
import Html exposing (..)
import Html.Attributes exposing (class, for, id, min, placeholder, style, type_, value)
import Html.Events exposing (keyCode, onInput, onSubmit, preventDefaultOn)
import Http exposing (Expect)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Page.Recipe.Editor.TagForm as TagForm
import Recipe exposing (Full, Recipe, fetch, fullDecoder)
import Recipe.Slug as Slug exposing (Slug)
import Route
import Session exposing (Session(..))
import Set exposing (Set)
import Task
import Url.Builder



-- MODEL


type alias Model =
    { session : Session
    , status : Status
    }


type Status
    = -- New Recipe
      EditingNew FormModel
    | Creating FormModel
      -- Edit Recipe
    | Loading Slug
    | LoadingFailed Slug
    | Editing Slug FormModel
    | Saving Slug FormModel


type alias FormModel =
    Form.View.Model Values


type alias Values =
    { title : String
    , description : String
    , instructions : String
    , portions : String
    , tags : List TagForm.Values
    }


type alias RecipeDetails =
    { title : String
    , description : Maybe String -- Maybe String ?
    , instructions : String
    , portions : String
    , tags : List TagForm.Tag
    }


initNew : Session -> ( Model, Cmd msg )
initNew session =
    ( { session = session
      , status =
            EditingNew
                ({ title = ""
                 , description = ""
                 , instructions = ""
                 , portions = "1"
                 , tags = [ TagForm.blank ]
                 }
                    |> Form.View.idle
                )
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
            EditingNew formModel ->
                div [] [ viewForm formModel ]

            Creating formModel ->
                viewForm formModel

            -- Editing an existing recipe
            Loading slug ->
                text "Laddar..."

            LoadingFailed slug ->
                text ("Kunde ej ladda in recept: " ++ Slug.toString slug)

            Editing slug formModel ->
                div [] [ viewForm formModel ]

            Saving slug formModel ->
                viewForm formModel
    }


viewForm : FormModel -> Html Msg
viewForm model =
    Form.View.asHtml
        { onChange = FormChanged
        , action = "Spara"
        , loading = "Sparar..."
        , validation = Form.View.ValidateOnSubmit
        }
        (Form.map Save form)
        model


form : Form Values RecipeDetails
form =
    let
        titleField =
            Form.textField
                { parser = Ok
                , value = .title
                , update = \value values -> { values | title = value }
                , error = always Nothing
                , attributes =
                    { label = "Titel"
                    , placeholder = "Gott recept..."
                    }
                }

        descriptionField =
            Form.textareaField
                { parser = Ok
                , value = .description
                , update = \value values -> { values | description = value }
                , error = always Nothing
                , attributes =
                    { label = "Beskrivning"
                    , placeholder = "Beskrivning av receptet..."
                    }
                }

        instructionsField =
            Form.textareaField
                { parser = Ok
                , value = .instructions
                , update = \value values -> { values | instructions = value }
                , error = always Nothing
                , attributes =
                    { label = "Instruktioner"
                    , placeholder = "Instruktioner till receptet..."
                    }
                }

        portionsField =
            Form.numberField
                { parser = Ok
                , value = .portions
                , update = \value values -> { values | portions = value }
                , error = always Nothing
                , attributes =
                    { label = "Portioner"
                    , placeholder = "Portioner..."
                    , step = Just 1
                    , min = Just 1
                    , max = Just 100
                    }
                }
    in
    Form.succeed RecipeDetails
        |> Form.append titleField
        |> Form.append (Form.optional descriptionField)
        |> Form.append instructionsField
        |> Form.append portionsField
        |> Form.append
            (Form.list
                { default =
                    TagForm.blank
                , value = .tags
                , update = \value values -> { values | tags = value }
                , attributes =
                    { label = "Taggar"
                    , add = Just "Lägg till tagg"
                    , delete = Just "Radera"
                    }
                }
                TagForm.form
            )


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


type Msg
    = Save RecipeDetails
    | FormChanged FormModel
      -- Msg:s from the server
    | CompletedCreate (Result ServerError (Recipe Full))
    | CompletedRecipeLoad Slug (Result Http.Error (Recipe Full))
    | CompletedEdit (Result ServerError (Recipe Full))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FormChanged newFormModel ->
            let
                updateStatus status =
                    case status of
                        EditingNew _ ->
                            EditingNew newFormModel

                        Saving slug _ ->
                            Saving slug newFormModel

                        Editing slug _ ->
                            Editing slug newFormModel

                        Creating _ ->
                            Creating newFormModel

                        _ ->
                            status
            in
            Debug.log (Debug.toString newFormModel)
                ( { model | status = updateStatus model.status }, Cmd.none )

        Save recipeDetails ->
            model.status
                |> save recipeDetails
                |> Tuple.mapFirst (\status -> { model | status = status })

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
                        ({ title = Slug.toString title
                         , description = description
                         , instructions = instructions
                         , portions = String.fromInt portions
                         , tags = List.map TagForm.Values tags

                         -- , newTagInput = ""
                         -- , newGroupInput = ""
                         -- , ingredients = ingredientsArray
                         }
                            |> Form.View.idle
                        )
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


save : RecipeDetails -> Status -> ( Status, Cmd Msg )
save recipeDetails status =
    case status of
        EditingNew formModel ->
            ( Creating formModel, create recipeDetails )

        Editing slug formModel ->
            ( Saving slug formModel, edit slug recipeDetails )

        _ ->
            ( status, Cmd.none )


savingError : ServerError -> Status -> Status
savingError error status =
    let
        problems =
            [ "Error saving " ++ serverErrorToString error ]
    in
    case status of
        Creating formModel ->
            EditingNew formModel

        Saving slug formModel ->
            Editing slug formModel

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


httpBodyFromValues : RecipeDetails -> Http.Body
httpBodyFromValues recipeDetails =
    let
        ingredientTuple ( groupName, current, ingredients ) =
            -- TODO: add current to ingredients but filter out empty ingredients
            -- <| Array.filter (\x -> String.length x > 0) <| Array.push current
            -- this should be done somewhere...
            ( groupName, Array.toList ingredients )

        -- ingredientDict =
        -- Dict.fromList <| Array.toList <| Array.map ingredientTuple recipeDetails.ingredients
        recipe =
            Encode.object
                [ ( "title", Encode.string recipeDetails.title )

                -- TODO: do note encode description at all if empty
                , ( "description", Encode.string <| Maybe.withDefault "" recipeDetails.description )
                , ( "instructions", Encode.string recipeDetails.instructions )
                , ( "portions", Encode.string recipeDetails.portions )

                -- , ( "tags", Encode.set Encode.string recipeDetails.tags )
                -- , ( "ingredients", Encode.dict identity (Encode.list Encode.string) ingredientDict )
                ]
    in
    Http.jsonBody recipe


edit : Slug -> RecipeDetails -> Cmd Msg
edit slug recipeDetails =
    Http.request
        { url = editUrl slug
        , method = "PATCH"
        , timeout = Nothing
        , tracker = Nothing
        , headers =
            [ Http.header "Prefer" "return=representation"
            , Http.header "Accept" "application/vnd.pgrst.object+json"
            ]
        , body = httpBodyFromValues recipeDetails
        , expect = expectJsonWithBody CompletedEdit Recipe.fullDecoder
        }


create : RecipeDetails -> Cmd Msg
create recipeDetails =
    Http.request
        { url = createUrl
        , method = "POST"
        , timeout = Nothing
        , tracker = Nothing
        , headers =
            [ Http.header "Prefer" "return=representation"
            , Http.header "Accept" "application/vnd.pgrst.object+json"
            ]
        , body = httpBodyFromValues recipeDetails
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



-- TODO: is this needed?


type TrimmedFormModel
    = Trimmed FormModel



{--
  - trimFields : Values -> TrimmedFormModel
  - trimFields formModel =
  -     Trimmed
  -         { title = String.trim formModel.title
  -         , description = String.trim formModel.description
  -         , instructions = String.trim formModel.instructions
  -         , portions = formModel.portions
  -         , tags = Set.map String.trim formModel.tags
  -         , newTagInput = formModel.newTagInput
  -         , newGroupInput = formModel.newGroupInput
  -         , ingredients = formModel.ingredients
  -         }
  --}


toSession : Model -> Session
toSession model =
    model.session
