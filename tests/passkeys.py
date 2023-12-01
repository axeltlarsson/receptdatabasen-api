import base64
import json
from base64 import urlsafe_b64encode

import copy
import pytest
import requests
from soft_webauthn import SoftWebauthnDevice

BASE_URL = "http://localhost:1234/rest"

VALID_USERNAME = "username"
VALID_PASSWORD = "password-password"


@pytest.fixture
def session():
    session = requests.Session()
    login_data = {
        "user_name": VALID_USERNAME,
        "password": VALID_PASSWORD,
    }
    response = session.post(f"{BASE_URL}/login", json=login_data)
    assert response.status_code == 200, "Login failed"
    return session


# Poor man's SETUP
def test_passkey_endpoint_delete(session):
    res = session.delete(f"{BASE_URL}/passkeys")
    assert res.status_code == 204


def test_login_success(session):
    response = session.get(BASE_URL + "/recipes")
    assert response.status_code == 200


def test_login_required_for_recipes():
    response = requests.get(BASE_URL + "/recipes")
    assert response.status_code == 401


# ----------------------|
# Passkey registration  |
# ----------------------|
def test_registration_begin(session):
    """
    Get passkey registration options from server by calling registration/begin
    """
    response = session.get(BASE_URL + "/passkeys/registration/begin")
    assert response.status_code == 200
    res_json = response.json()

    assert "rp" in res_json
    assert "challenge" in res_json
    assert "user" in res_json


def serialize_passkey(key):
    s = copy.deepcopy(key)
    s["id"] = s["id"].decode("utf-8").rstrip("=")
    s["rawId"] = urlsafe_b64encode(s["rawId"]).decode("utf-8").rstrip("=")
    s["response"]["clientDataJSON"] = base64.b64encode(
        s["response"]["clientDataJSON"]
    ).decode("utf-8")
    if "attestationObject" in s["response"]:
        s["response"]["attestationObject"] = base64.b64encode(
            s["response"]["attestationObject"]
        ).decode("utf-8")

    if "signature" in s["response"]:
        s["response"]["signature"] = base64.b64encode(
            s["response"]["signature"]
        ).decode("utf-8")
    if "authenticatorData" in s["response"]:
        s["response"]["authenticatorData"] = base64.b64encode(
            s["response"]["authenticatorData"]
        ).decode("utf-8")

    return json.dumps(s)


# our fake device
device = SoftWebauthnDevice()


@pytest.fixture
def passkey_with_session(session):
    """
    Fixture that creates a passkey using registration options from the server.
    Returns (passkey, session)
    """
    response = session.get(BASE_URL + "/passkeys/registration/begin")
    assert response.status_code == 200

    # decode response
    res_json = response.json()
    options = {"publicKey": res_json}
    challenge = options["publicKey"]["challenge"]
    options["publicKey"]["challenge"] = base64.urlsafe_b64decode(challenge + "==")

    # create a passkey (aka public key credential - attestation) akin to `navigator.credentials.create()`
    passkey = device.create(options, "http://localhost:1234")

    return passkey, session


def test_registration_complete(passkey_with_session):
    passkey, session = passkey_with_session
    response = session.post(
        f"{BASE_URL}/passkeys/registration/complete", json=serialize_passkey(passkey)
    )
    body = response.json()
    assert response.status_code == 200
    assert "credential_id" in body
    assert body["user_verified"] is False  # soft webauthn performs no user verification

    # get the passkeys from the server
    passkey, session = passkey_with_session
    res = session.get(f"{BASE_URL}/passkeys")
    assert res.status_code == 200

    body = res.json()
    last_passkey = body[-1]
    passkey_json = json.loads(serialize_passkey(passkey))

    assert last_passkey["data"]["credential_id"] == passkey_json["id"]


def test_bogus_authentication_complete(session):
    response = session.post(
        f"{BASE_URL}/passkeys/registration/complete", json={"hej": False}
    )
    assert response.status_code == 400
    assert response.json()


# ------------------------|
# Passkey authentication  |
# ------------------------|
@pytest.fixture
def auth_options_w_session():
    """
    Fixture to get authentication options from the server at /passkeys/authentication/begin
    Returns the authentication options as well as the session associated (needed for the challenge)
    """
    # the server needs to know the username in order to fetch allowed credentials
    payload = {"user_name": VALID_USERNAME}
    session = requests.Session()
    response = session.post(f"{BASE_URL}/passkeys/authentication/begin", json=payload)

    assert response.status_code == 200
    body = response.json()

    # Decode the challenge from base64-url and convert to bytes
    challenge = base64.urlsafe_b64decode(body["challenge"] + "==")

    # Update the body with the byte-encoded challenge
    body["challenge"] = challenge

    assert "challenge" in body
    assert body["rpId"] == "localhost"
    assert "allowCredentials" in body

    return {"publicKey": body}, session


def test_bogus_auth_begin(session):
    res = session.post(
        f"{BASE_URL}/passkeys/authentication/begin", json={"bogus": True}
    )
    assert res.status_code == 400
    assert res.json()


@pytest.fixture
def get_passkey_w_session(auth_options_w_session):
    """
    Fixture to get the passkey from soft_webauthn device, also returns the session
    """
    auth_options, session = auth_options_w_session
    # get authentication credential aka assertion
    passkey = device.get(options=auth_options, origin="http://localhost:1234")
    assert passkey["type"] == "public-key", session

    return passkey, session


def test_incomplete_passkey_auth(auth_options_w_session):
    """
    The session we get from passkeys/begin should only allow us to call passkeys/complete, no other endpoints.
    """

    _, session = auth_options_w_session
    res = session.get(f"{BASE_URL}/recipes")
    assert res.status_code == 401


def test_bogus_auth_complete(session):
    res = session.post(
        f"{BASE_URL}/passkeys/authentication/complete", json={"bogus": "hej"}
    )
    assert res.status_code == 400
    assert res.json()


def test_authentication_complete(get_passkey_w_session):
    passkey, session = get_passkey_w_session

    payload = serialize_passkey(passkey)
    response = session.post(
        f"{BASE_URL}/passkeys/authentication/complete", json=payload
    )
    assert response.status_code == 200
    response_json = response.json()
    assert "me" in response_json
    assert response_json["me"]["user_name"] == VALID_USERNAME
    with pytest.raises(KeyError):
        # token should be stripped by openresty
        response_json["token"]

    res = session.get(f"{BASE_URL}/recipes")
    assert res.status_code == 200
    assert res.json()


# Poor man's teardown
def test_teardown(session):
    res = session.delete(f"{BASE_URL}/passkeys")
    assert res.status_code == 204
