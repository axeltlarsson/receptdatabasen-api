module Page.NotFound exposing (view)

import Element exposing (Element, column, el, text)
import Element.Region as Region



-- VIEW


view : { title : String, stickyContent : Element msg, content : Element msg }
view =
    { title = "Page Not Found"
    , stickyContent = Element.none
    , content = column [ Region.mainContent ] [ el [] (text "Not found") ]
    }
