module Page.Recipe.Markdown exposing (onlyListAndHeading, parsingErrors, render)

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
        , padding
        , paddingEach
        , paddingXY
        , paragraph
        , rgb255
        , rgba255
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
import Html
import Html.Attributes
import Markdown.Block as Block exposing (Block, Inline, ListItem(..), Task(..))
import Markdown.Html
import Markdown.Parser
import Markdown.Renderer
import Palette


render : String -> Dict Int Bool -> (Int -> Bool -> msg) -> Result String (List (Element msg))
render markdown checkboxStatus clickedCheckbox =
    markdown
        |> Markdown.Parser.parse
        |> Result.mapError (\e -> e |> List.map Markdown.Parser.deadEndToString |> String.join "\n")
        |> Result.andThen (Markdown.Renderer.render (renderer checkboxStatus clickedCheckbox))


all : (Block -> Bool) -> String -> Bool
all predicate markdown =
    let
        astResult =
            Markdown.Parser.parse markdown
    in
    case astResult of
        Ok blocks ->
            blocks
                |> Block.foldl
                    (\block soFar ->
                        soFar && predicate block
                    )
                    True

        Err _ ->
            False


parsingErrors : String -> Maybe String
parsingErrors markdown =
    let
        astResult =
            Markdown.Parser.parse markdown
    in
    case astResult of
        Ok _ ->
            Nothing

        Err errors ->
            errors |> List.map Markdown.Parser.deadEndToString |> String.join "\n" |> Just


onlyListAndHeading : String -> Bool
onlyListAndHeading input =
    all
        (\block ->
            case block of
                Block.Heading _ _ ->
                    True

                Block.UnorderedList _ ->
                    True

                _ ->
                    False
        )
        input


renderer : Dict Int Bool -> (Int -> Bool -> msg) -> Markdown.Renderer.Renderer (Element msg)
renderer checkboxStatus clickedCheckbox =
    { heading = heading
    , paragraph = paragraph [ spacing 10 ]
    , thematicBreak = Element.none
    , text = \t -> paragraph [ width fill ] [ text t ]
    , strong = row [ Font.bold ]
    , emphasis = row [ Font.italic ]
    , codeSpan = text
    , link =
        \{ title, destination } body ->
            Element.newTabLink
                [ Element.htmlAttribute (Html.Attributes.style "display" "inline-flex") ]
                { url = destination
                , label =
                    Element.paragraph
                        [ Font.color (Element.rgb255 0 0 255)
                        ]
                        body
                }
    , hardLineBreak = Html.br [] [] |> Element.html
    , image = \image -> Element.image [ width fill ] { src = image.src, description = image.alt }
    , blockQuote =
        \children ->
            Element.column
                [ Border.widthEach { top = 0, right = 0, bottom = 0, left = 10 }
                , Element.padding 10
                , Border.color (Element.rgb255 145 145 145)
                , Background.color (Element.rgb255 245 245 245)
                ]
                children
    , unorderedList = unorderedList checkboxStatus clickedCheckbox
    , orderedList = orderedList
    , codeBlock = \s -> Element.none
    , html =
        Markdown.Html.oneOf
            [ iframe

            -- Markdown.Html.tag "iframe" iframe |> Markdown.Html.withAttribute "src"
            ]
    , table = column []
    , tableHeader = column []
    , tableBody = column []
    , tableRow = row []
    , tableHeaderCell = \maybeAlignment children -> paragraph [] children
    , tableCell = \maybeAlignment children -> paragraph [] children
    }


iframe : Markdown.Html.Renderer (a -> Element msg)
iframe =
    Markdown.Html.tag "iframe"
        (\src children ->
            text ("iframe: " ++ src)
        )
        |> Markdown.Html.withAttribute "src"


heading : { level : Block.HeadingLevel, rawText : String, children : List (Element msg) } -> Element msg
heading { level, rawText, children } =
    paragraph
        [ Font.size
            (case level of
                Block.H1 ->
                    Palette.large

                Block.H2 ->
                    Palette.medium

                _ ->
                    Palette.normal
            )
        , Font.regular
        , Region.heading (Block.headingLevelToInt level)
        , paddingEach { edges | bottom = 15, top = 15 }
        ]
        children


edges =
    { top = 0
    , right = 0
    , bottom = 0
    , left = 0
    }


unorderedList : Dict Int Bool -> (Int -> Bool -> msg) -> List (ListItem (Element msg)) -> Element msg
unorderedList checkboxStatus clickedCheckbox items =
    column [ spacing 15, width fill ]
        (items
            |> List.indexedMap
                (\idx (ListItem task children) ->
                    row [ width fill ]
                        [ case task of
                            NoTask ->
                                row [ width fill, spacing 10 ] ([ text "•" ] ++ children)

                            _ ->
                                -- IncompleteTask and CompletedTask - both treated the same
                                let
                                    checked =
                                        Dict.get idx checkboxStatus |> Maybe.withDefault False
                                in
                                row [ width fill, spacing 10 ]
                                    [ Input.checkbox
                                        [ alignLeft, alignTop, width (Element.px 15) ]
                                        { onChange = clickedCheckbox idx
                                        , icon = Input.defaultCheckbox
                                        , checked = checked
                                        , label = Input.labelHidden "checkbox"
                                        }
                                    , row
                                        [ width fill
                                        , if checked then
                                            Font.color Palette.lightGrey

                                          else
                                            Font.color Palette.nearBlack
                                        ]
                                        [ row [ width fill, Element.pointer, Events.onClick (clickedCheckbox idx (not checked)) ] children ]
                                    ]
                        ]
                )
        )


orderedList : Int -> List (List (Element msg)) -> Element msg
orderedList startingIndex items =
    column [ spacing 15, width fill ]
        (items
            |> List.indexedMap
                (\index itemBlocks ->
                    row [ spacing 5, width fill ]
                        [ row [ width fill, spacing 5 ]
                            (el [ alignTop ] (text (String.fromInt (index + startingIndex) ++ ". "))
                                :: itemBlocks
                            )
                        ]
                )
        )
