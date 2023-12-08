module Palette exposing (..)

import Element exposing (rgb255, rgba255)
import Element.Border as Border
import Element.Font as Font


{-|

    from <https://coolors.co/8be1d8-454851-fceff9-db5375-b95f89>

-}
middleBlueGreen : Element.Color
middleBlueGreen =
    rgb255 139 225 216


charcoal : Element.Color
charcoal =
    rgb255 69 72 81


lavenderBlush : Element.Color
lavenderBlush =
    rgb255 252 239 249


blush : Element.Color
blush =
    rgb255 219 83 117


pictorialCarmine : Element.Color
pictorialCarmine =
    rgb255 185 39 76


mulberry : Element.Color
mulberry =
    rgb255 185 95 137



{--
  - Colours
  --}


black : Element.Color
black =
    rgb255 0 0 0


grey : Element.Color
grey =
    rgb255 104 92 93


lightGrey : Element.Color
lightGrey =
    rgb255 220 220 220


darkGrey : Element.Color
darkGrey =
    rgb255 205 205 205


nearBlack : Element.Color
nearBlack =
    rgb255 26 17 16


white : Element.Color
white =
    rgb255 255 255 255


red : Element.Color
red =
    rgb255 255 0 0


green : Element.Color
green =
    rgba255 50 224 196 1


orange : Element.Color
orange =
    rgb255 255 127 0



{--
  - Typography
  --}


small : Int
small =
    10


normal : Int
normal =
    20


medium : Int
medium =
    24


large : Int
large =
    28


xLarge : Int
xLarge =
    42


xxLarge : Int
xxLarge =
    48


textShadow : Element.Attribute msg
textShadow =
    Font.shadow { offset = ( 0, 1 ), blur = 1, color = black }


edges =
    { top = 0
    , right = 0
    , bottom = 0
    , left = 0
    }



{--
  - Card shadow
  - https://codepen.io/sdthornton/pen/wBZdXq
  --}


cardShadow1 : Element.Attribute msg
cardShadow1 =
    Border.shadow
        { offset = ( 0, 3 )
        , size = 0
        , blur = 6
        , color = Element.rgba 0 0 0 0.16
        }


cardShadow2 : Element.Attribute msg
cardShadow2 =
    Border.shadow
        { offset = ( 0, 3 )
        , size = 0
        , blur = 6
        , color = Element.rgba 0 0 0 0.23
        }
