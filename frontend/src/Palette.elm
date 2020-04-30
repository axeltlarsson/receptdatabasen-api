module Palette exposing (..)

import Element exposing (rgb255, rgba255)
import Element.Background as Background
import Element.Font as Font


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


large : Int
large =
    24


textShadow : Element.Attribute msg
textShadow =
    Font.shadow { offset = ( 0, 1 ), blur = 1, color = black }
