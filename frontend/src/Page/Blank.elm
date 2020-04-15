module Page.Blank exposing (view)

import Element exposing (Element)



-- VIEW


view : { title : String, content : Element msg }
view =
    { title = ""
    , content = Element.none
    }
