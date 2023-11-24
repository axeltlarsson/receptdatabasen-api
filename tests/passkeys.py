import base64
import json
from base64 import urlsafe_b64encode

import pytest
import requests
from soft_webauthn import SoftWebauthnDevice

BASE_URL = "http://localhost:1234/rest"

LOGIN_ENDPOINT = "/login"

VALID_USERNAME = "username"
VALID_PASSWORD = "password-password"


@pytest.fixture
def api_url():
    return BASE_URL + LOGIN_ENDPOINT


@pytest.fixture
def session(api_url):
    session = requests.Session()
    login_data = {
        "user_name": VALID_USERNAME,
        "password": VALID_PASSWORD,
    }
    response = session.post(api_url + LOGIN_ENDPOINT, json=login_data)
    assert response.status_code == 200, "Login failed"
    return session


def test_login_success(session):
    response = session.get(BASE_URL + "/recipes")
    assert response.status_code == 200


def test_login_required_for_recipes():
    response = requests.get(BASE_URL + "/recipes")
    assert response.status_code == 401


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
    serialized = key.copy()
    serialized["id"] = key["id"].decode("utf-8").rstrip("=")
    serialized["rawId"] = urlsafe_b64encode(key["rawId"]).decode("utf-8").rstrip("=")
    serialized["response"]["clientDataJSON"] = base64.b64encode(
        key["response"]["clientDataJSON"]
    ).decode("utf-8")
    serialized["response"]["attestationObject"] = base64.b64encode(
        key["response"]["attestationObject"]
    ).decode("utf-8")

    return json.dumps(serialized)


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

    # create a passkey akin to `navigator.credentials.create()`
    device = SoftWebauthnDevice()
    passkey = device.create(options, "http://localhost:1234")
    passkey_serialized = serialize_passkey(passkey)

    return passkey_serialized, session


def test_registration_complete(passkey_with_session):
    passkey, session = passkey_with_session
    response = session.post(BASE_URL + "/passkeys/registration/complete", json=passkey)
    body = response.json()
    assert response.status_code == 200
    assert "credential_id" in body
    assert body["user_verified"] is False # soft webauthn performs no user verification
