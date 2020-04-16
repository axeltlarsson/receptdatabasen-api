module Loading exposing (animation, error)

import Element exposing (Element, row, text)
import Element.Background as Background
import Html exposing (Html, div)
import Html.Attributes exposing (class, id)
import Palette


animation : Html msg
animation =
    div [ id "hourglass-loader" ]
        [ div [ id "hourglass-top" ] []
        , div [ id "hourglass-bottom" ] []
        , div [ id "hourglass-line" ] []
        ]


error : String -> String -> Element msg
error title message =
    row [ Background.color Palette.red ]
        [ text title
        , text message
        ]
