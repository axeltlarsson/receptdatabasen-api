module Page.Blank exposing (view)

import Element exposing (Element)



-- VIEW


view : { title : String, stickyContent : Element msg, content : Element msg }
view =
    { title = ""
    , stickyContent = Element.none
    , content = Element.none
    }
