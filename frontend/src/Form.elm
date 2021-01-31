module Form exposing (errorBorder, onEnter, validateSingle, viewValidationError)

import Element exposing (Element, el, text)
import Element.Border as Border
import Element.Font as Font
import Html
import Html.Events
import Json.Decode as Decode
import Palette
import Verify


onEnter : msg -> Html.Attribute msg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                Decode.succeed ( msg, True )

            else
                Decode.fail "not ENTER"
    in
    Html.Events.preventDefaultOn "keydown" (Decode.andThen isEnter Html.Events.keyCode)


viewValidationError : Bool -> a -> Verify.Validator String a b -> Element msg
viewValidationError active input theValidator =
    if active then
        case validateSingle input theValidator of
            Ok _ ->
                Element.none

            Err ( err, _ ) ->
                el
                    [ Font.color Palette.red ]
                    (text err)

    else
        Element.none


validateSingle : a -> Verify.Validator String a b -> Result ( String, List String ) b
validateSingle value theValidator =
    (Verify.validate identity
        |> Verify.verify (\_ -> value) theValidator
    )
        value


errorBorder : Bool -> a -> Verify.Validator String a String -> List (Element.Attribute msg)
errorBorder active input theValidator =
    let
        fieldIsInvalid =
            case validateSingle input theValidator of
                Ok _ ->
                    False

                Err _ ->
                    True
    in
    if active && fieldIsInvalid then
        [ Border.width 1
        , Border.rounded 2
        , Border.color Palette.red
        ]

    else
        []
