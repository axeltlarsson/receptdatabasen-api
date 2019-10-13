module Loading exposing (animation, error)

import Html exposing (..)
import Html.Attributes exposing (class, id)


animation : Html msg
animation =
    div [ id "hourglass-loader" ]
        [ div [ id "hourglass-top" ] []
        , div [ id "hourglass-bottom" ] []
        , div [ id "hourglass-line" ] []
        ]


error : String -> String -> Html msg
error title message =
    div [ class "toast toast--error" ]
        [ h6 [] [ text title ]
        , code [] [ text message ]
        ]
