import pytest
import requests
import json


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


expected_register_request_response = json.loads(
    """
{
  "rp": {
    "name": "receptdatabasen",
    "id": "localhost"
  },
  "user": {
    "id": "AAAAAw==",
    "name": "familjen",
    "displayName": "familjen"
  },
  "challenge": "vGlIST2cUHChzmDh",
  "pubKeyCredParams": [
    {
      "alg": -7,
      "type": "public-key"
    },
    {
      "alg": -257,
      "type": "public-key"
    }
  ],
  "timeout": 1800000,
  "attestation": "none",
  "excludeCredentials": [],
  "authenticatorSelection": {
    "userVerification": "required",
    "authenticatorAttachment": "platform"
  }
}
"""
)


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


@pytest.fixture
def registration_options():
    """
    Fixture to get a prerecorded credential to verify
    """
    with open("example_resp.json") as resp:
        return json.loads(resp.read())


def test_registration_complete(session, registration_options):
    # first need to POST to /passkeys/registration/begin to get the challenge in our session
    test_registration_begin(session)
    response = session.post(
        BASE_URL + "/passkeys/registration/complete", json=registration_options
    )
    assert (
        response.status_code == 403
    )  # TODO: 403 since challenge is not going to match
