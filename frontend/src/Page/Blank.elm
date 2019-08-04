module Page.Blank exposing (view)

import Html exposing (..)



-- VIEW


view : { title : String, content : Html msg }
view =
    { title = ""
    , content = text ""
    }
