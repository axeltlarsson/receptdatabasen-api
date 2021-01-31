module Loading exposing (animation)

import Html exposing (Html, div)
import Html.Attributes exposing (id)


animation : Html msg
animation =
    div [ id "hourglass-loader" ]
        [ div [ id "hourglass-top" ] []
        , div [ id "hourglass-bottom" ] []
        , div [ id "hourglass-line" ] []
        ]
