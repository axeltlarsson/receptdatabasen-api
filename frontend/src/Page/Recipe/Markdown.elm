module Page.Recipe.Markdown exposing (onlyListAndHeading, parsingErrors, render)

import Dict exposing (Dict)
import Element
    exposing
        ( Element
        , alignLeft
        , alignRight
        , alignTop
        , column
        , el
        , fill
        , height
        , htmlAttribute
        , paddingEach
        , paragraph
        , row
        , spacing
        , spacingXY
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
import Html
import Html.Attributes
import Markdown.Block as Block exposing (Block, ListItem(..), Task(..))
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


overflowWrap : Element.Attribute msg
overflowWrap =
    Element.htmlAttribute <| Html.Attributes.style "overflow-wrap" "anywhere"


renderer : Dict Int Bool -> (Int -> Bool -> msg) -> Markdown.Renderer.Renderer (Element msg)
renderer checkboxStatus clickedCheckbox =
    { heading = heading
    , paragraph = paragraph [ overflowWrap, spacing 10 ]
    , thematicBreak = Element.none
    , text = \t -> paragraph [ overflowWrap ] [ text t ]
    , strong = paragraph [ Font.bold ]
    , emphasis = paragraph [ Font.italic ]
    , codeSpan = text
    , link =
        \{ destination } body ->
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
    , codeBlock = \_ -> Element.none
    , html =
        Markdown.Html.oneOf [ youtube ]
    , table = column []
    , tableHeader = column []
    , tableBody = column []
    , tableRow = row []
    , tableHeaderCell = \_ children -> paragraph [] children
    , tableCell = \_ children -> paragraph [] children
    }


youtube : Markdown.Html.Renderer (a -> Element msg)
youtube =
    Markdown.Html.tag "youtube"
        (\url _ _ ->
            el
                [ htmlAttribute (Html.Attributes.class "iframe-container")
                , width fill
                , height fill
                ]
                (Element.html <|
                    Html.iframe
                        [ Html.Attributes.src url
                        , Html.Attributes.width 560
                        , Html.Attributes.height 315
                        , Html.Attributes.attribute "frameborder" "0"
                        , Html.Attributes.attribute "allow" "autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                        , Html.Attributes.attribute "allowfullscreen" ""
                        , Html.Attributes.attribute "style" "width: 100%; height: 100%;"
                        ]
                        []
                )
        )
        |> Markdown.Html.withAttribute "url"
        |> Markdown.Html.withAttribute "thumb"


heading : { level : Block.HeadingLevel, rawText : String, children : List (Element msg) } -> Element msg
heading { level, children } =
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



-- TODO: support multiple lists of independent checkboxes (if you have more than one list currently,
-- every i:th item will be clicked because index is not globally unique)


circleIcon =
    el []
        (FeatherIcons.circle |> FeatherIcons.toHtml [] |> Element.html)


checkIcon =
    el []
        (FeatherIcons.check |> FeatherIcons.toHtml [] |> Element.html)


unorderedList : Dict Int Bool -> (Int -> Bool -> msg) -> List (ListItem (Element msg)) -> Element msg
unorderedList checkboxStatus clickedCheckbox items =
    column [ spacing 15, width fill ]
        (items
            |> List.indexedMap
                (\idx (ListItem task children) ->
                    el [ width fill ]
                        (case task of
                            NoTask ->
                                row [ width fill, spacingXY 25 0 ]
                                    [ el [ alignRight, alignTop, width (Element.px 15), Font.size 25, paddingEach { edges | left = 8 } ] (text "•")
                                    , paragraph [] children
                                    ]

                            _ ->
                                -- IncompleteTask and CompletedTask - both treated the same
                                let
                                    checked =
                                        Dict.get idx checkboxStatus |> Maybe.withDefault False
                                in
                                row [ width fill, spacingXY 25 0 ]
                                    [ Input.checkbox
                                        [ alignLeft, alignTop, width (Element.px 15) ]
                                        { onChange = clickedCheckbox idx
                                        , icon =
                                            \x ->
                                                if x then
                                                    checkIcon

                                                else
                                                    circleIcon
                                        , checked = checked
                                        , label = Input.labelHidden "checkbox"
                                        }
                                    , row
                                        [ width fill
                                        , alignTop
                                        , if checked then
                                            Font.color Palette.lightGrey

                                          else
                                            Font.color Palette.nearBlack
                                        ]
                                        [ paragraph [ Element.pointer, Events.onClick (clickedCheckbox idx (not checked)) ] children ]
                                    ]
                        )
                )
        )


orderedList : Int -> List (List (Element msg)) -> Element msg
orderedList startingIndex items =
    column [ spacing 15, width fill ]
        (items
            |> List.indexedMap
                (\index children ->
                    row [ width fill, spacingXY 15 0 ]
                        [ row
                            [ alignTop
                            , Font.heavy
                            , width (Element.px 15)
                            , paddingEach { edges | top = 2 }
                            ]
                            [ text (String.fromInt (index + startingIndex) ++ ".") ]
                        , paragraph [] children
                        ]
                )
        )
