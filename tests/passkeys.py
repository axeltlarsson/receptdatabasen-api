import pytest
import requests
import json
from urllib.parse import parse_qs


BASE_URL = "http://localhost:1234/rest"

# The login endpoint path (modify if needed)
LOGIN_ENDPOINT = "/login"

# Replace these with valid test credentials for your API
VALID_USERNAME = "familjen"
VALID_PASSWORD = "utbud-sirap-ryss-plank"


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


@pytest.fixture
def register_request(session):
    """
    Save stuff
    """
    response = session.get(BASE_URL + "/passkey_register_request")
    assert response.status_code == 200
    res_json = response.json()
    assert "rp" in res_json
    assert "challenge" in res_json

    # TODO: create "real" passkey?

    with open("example_resp.json") as resp:
        return json.loads(resp.read())


def test_passkey_register_response(session, register_request):
    response = session.post(
        BASE_URL + "/passkey_register_response", json=register_request
    )
    print(response.text)
    assert response.status_code == 200
