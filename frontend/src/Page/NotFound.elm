module Page.NotFound exposing (view)

import Element exposing (Element, column, el, text)
import Element.Region as Region



-- VIEW


view : { title : String, content : Element msg }
view =
    { title = "Page Not Found"
    , content = column [ Region.mainContent ] [ el [] (text "Not found") ]
    }
