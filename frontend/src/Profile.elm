module Profile exposing (Passkey, Profile, fetch, fetchPasskeys, passkeyAuthenticationBegin, passkeyRegistrationBegin, passkeyRegistrationComplete)

import Api exposing (ServerError, expectJsonWithBody)
import Http
import Json.Decode as Decode exposing (field, int, nullable, string)
import Json.Encode as Encode
import Url.Builder


type alias Profile =
    { userName : String
    , role : String
    , email : Maybe String
    , id : Int
    }


type alias Passkey =
    { credentialId : String
    , signCount : Int
    , createdAt : String -- TODO: handle DATES?
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
            [ Http.header "Accept" "application/json"
            , Http.header "Content-type" "application/json"
            ]
        , url =
            Url.Builder.crossOrigin "/rest"
                [ "passkeys" ]
                [ Url.Builder.string "select" "id,data,created_at"
                ]
        , body = Http.emptyBody
        , expect = expectJsonWithBody toMsg passkeyDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


passkeyDecoder : Decode.Decoder (List Passkey)
passkeyDecoder =
    Decode.list
        (Decode.map3 Passkey
            (field "data" <| field "credential_id" string)
            (field "data" <| field "sign_count" int)
            (field "created_at" string)
        )


passkeyRegistrationBegin : (Result ServerError Encode.Value -> msg) -> Cmd msg
passkeyRegistrationBegin toMsg =
    Http.request
        { method = "GET"
        , headers =
            [ Http.header "Accept" "application/json"
            , Http.header "Content-type" "application/json"
            ]
        , url =
            Url.Builder.crossOrigin "/rest"
                [ "passkeys", "registration", "begin" ]
                []
        , body = Http.emptyBody
        , expect = expectJsonWithBody toMsg Decode.value
        , timeout = Nothing
        , tracker = Nothing
        }


passkeyRegistrationComplete : Encode.Value -> (Result ServerError Encode.Value -> msg) -> Cmd msg
passkeyRegistrationComplete body toMsg =
    Http.request
        { method = "POST"
        , headers =
            [ Http.header "Accept" "application/json"
            ]
        , url =
            Url.Builder.crossOrigin "/rest"
                [ "passkeys", "registration", "complete" ]
                []
        , body = Http.jsonBody body
        , expect = expectJsonWithBody toMsg Decode.value
        , timeout = Nothing
        , tracker = Nothing
        }


passkeyAuthenticationBegin : String -> (Result ServerError Encode.Value -> msg) -> Cmd msg
passkeyAuthenticationBegin userName toMsg =
    let
        body =
            Encode.object
                [ ( "user_name", Encode.string userName )
                ]
    in
    Http.request
        { method = "POST"
        , headers =
            [ Http.header "Accept" "application/json"
            ]
        , url =
            Url.Builder.crossOrigin "/rest"
                [ "passkeys", "authentication", "begin" ]
                []
        , body = Http.jsonBody body
        , expect = expectJsonWithBody toMsg Decode.value
        , timeout = Nothing
        , tracker = Nothing
        }
