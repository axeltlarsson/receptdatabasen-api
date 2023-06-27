module Profile exposing (Passkey, Profile, fetch, fetchPasskeys)

import Api exposing (ServerError, expectJsonWithBody)
import Http
import Json.Decode as Decode exposing (field, int, nullable, string)
import Url.Builder


type alias Profile =
    { userName : String
    , role : String
    , email : Maybe String
    , id : Int
    }


type alias Passkey =
    { id : String
    , publicKey : String
    , device : String
    }


fetch : (Result ServerError Profile -> msg) -> Cmd msg
fetch toMsg =
    Http.request
        { method = "GET"
        , headers =
            [ Http.header "Accept" "application/vnd.pgrst.object+json"
            , Http.header "Content-type" "application/json"
            ]
        , url = Url.Builder.crossOrigin "/rest" [ "rpc", "me" ] []
        , body = Http.emptyBody
        , expect = expectJsonWithBody toMsg profileDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


profileDecoder : Decode.Decoder Profile
profileDecoder =
    Decode.map4 Profile
        (field "user_name" string)
        (field "role" string)
        (field "email" <| nullable string)
        (field "id" int)


fetchPasskeys : (Result ServerError (List Passkey) -> msg) -> Cmd msg
fetchPasskeys toMsg =
    Http.request
        { method = "GET"
        , headers =
            [ Http.header "Accept" "application/vnd.pgrst.object+json"
            , Http.header "Content-type" "application/json"
            ]
        , url = Url.Builder.crossOrigin "/rest" [ "rpc", "passkeys" ] []
        , body = Http.emptyBody
        , expect = expectJsonWithBody toMsg passkeyDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


passkeyDecoder : Decode.Decoder (List Passkey)
passkeyDecoder =
    Decode.list
        (Decode.map3 Passkey
            (field "id" string)
            (field "publicKey" string)
            (field "device" string)
        )
