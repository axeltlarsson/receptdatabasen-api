module Page.NotFound exposing (view)

import Html exposing (..)



-- VIEW


view : { title : String, content : Html msg }
view =
    { title = "Page Not Found"
    , content = main_ [] [ h1 [] [ text "Not found" ] ]
    }
