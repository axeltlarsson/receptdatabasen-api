module Api exposing (ServerError(..), expectJsonWithBody, viewServerError, errorFromString)

import Element exposing (Element, column, el, fill, paddingEach, paragraph, row, spacing, text, width)
import Element.Font as Font
import FeatherIcons
import Http exposing (Expect)
import Json.Decode as Decode exposing (Decoder)
import Palette



{--
  - This module is modeled after rtfeldman's elm-spa-example: https://github.com/rtfeldman/elm-spa-example/blob/master/src/Api.elm
  - However, it is only a start, I won't immediately follow his design, as I think it is slightly overkill for my use case
  - I essentially only have two "Endpoint":s so using that abstraction for me feels overkill: Login and Recipe
  - However, I do have some code that I need to share, and I put that here
--}


expectJsonWithBody : (Result ServerError a -> msg) -> Decoder a -> Expect msg
expectJsonWithBody toMsg decoder =
    Http.expectStringResponse toMsg <|
        \response ->
            case response of
                Http.BadUrl_ urll ->
                    Err (otherHttpError (Http.BadUrl urll) Nothing)

                Http.Timeout_ ->
                    Err (otherHttpError Http.Timeout Nothing)

                Http.NetworkError_ ->
                    Err (otherHttpError Http.NetworkError Nothing)

                Http.BadStatus_ { statusCode } body ->
                    case statusCode of
                        401 ->
                            Err Unauthorized

                        _ ->
                            Err (otherHttpError (Http.BadStatus statusCode) (Just body))

                Http.GoodStatus_ _ body ->
                    let
                        jsonBodyStr =
                            case body of
                                "" ->
                                    "{}"

                                j ->
                                    j
                    in
                    case Decode.decodeString decoder jsonBodyStr of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err (otherHttpError (Http.BadBody (Decode.errorToString err)) (Just body))



{--
  - ServerError
  - I specifically care about Unauthorized case - then we want to redirect to /login
  - otherwise, I keep the type opaque, modules are expected to basically just pass it to
  - viewServerError, if they wish to display the error to user
  --}


type ServerError
    = Unauthorized
    | Error OtherError


type OtherError
    = OtherHttpError Http.Error (Maybe Body)
    | OtherErr String


otherHttpError : Http.Error -> Maybe Body -> ServerError
otherHttpError httpError body =
    Error (OtherHttpError httpError body)

errorFromString : String -> ServerError
errorFromString err =
    Error (OtherErr err)


type alias Body =
    String


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl str ->
            "🔎 BadUrl " ++ str

        Http.Timeout ->
            "⌛Timeout"

        Http.NetworkError ->
            "🌐 NetworkError"

        Http.BadStatus code ->
            "🔥 BadStatus " ++ String.fromInt code

        Http.BadBody str ->
            "🧐 BadBody " ++ str


viewServerError : String -> ServerError -> Element msg
viewServerError prefix serverError =
    let
        alertIcon =
            el [ paddingEach { left = 0, right = 10, top = 0, bottom = 0 }, Font.color Palette.red ]
                (FeatherIcons.alertTriangle |> FeatherIcons.toHtml [] |> Element.html)

        wrapError status errBody =
            column [ width fill, spacing 10 ]
                [ row [ Font.heavy ] [ alertIcon, text prefix ]
                , el [ Font.family [ Font.typeface "Courier New", Font.monospace ], Font.heavy ] (text status)
                , errBody
                    |> Maybe.map (\err -> paragraph [ Font.family [ Font.typeface "Courier New", Font.monospace ] ] [ text err ])
                    |> Maybe.withDefault Element.none
                ]
    in
    case serverError of
        Error (OtherHttpError httpError Nothing) ->
            wrapError (httpErrorToString httpError) Nothing

        Error (OtherHttpError httpError (Just body)) ->
            wrapError (httpErrorToString httpError) (Just body)

        Error (OtherErr err) ->
            wrapError "Error" (Just err)

        Unauthorized ->
            wrapError "401 Unauthorized" Nothing
