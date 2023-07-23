create or replace view api.passkeys as (
  select
    id,
    user_id,
    public_key,
    updated_at,
    created_at
  from data.passkey
);

alter view api.passkeys owner to api;

CREATE OR REPLACE FUNCTION api.disabled() RETURNS trigger
  LANGUAGE plpgsql
  AS $$
BEGIN
  RAISE EXCEPTION 'Uploading raw passkeys is not allowed'
    USING DETAIL = 'Passkeys need to be registered in a two step process - first to obtain the configuration/challenge for the client - then to register the passkey',
          HINT = 'Use /rpc/passkey_register_request and /rpc/passkey_register_response to add a new passkey';
END
$$;

create trigger forbid_passkey_insertion
instead of insert or update on api.passkeys
for each row execute procedure api.disabled();


-- TODO: move to lib/helpers
-- TODO: no need with Python right
create or replace function api.base64url(bytes bytea)
returns text as $$
/*
   Function: base64url

   Description: base64url encodes the input

   Parameters:
     - bytes: The bytes to generate.

   Returns: Base64url-encoded value as TEXT.

   Example usage:
     select base64url(gen_random_bytes(16)); -- Generate 16 bytes (128 bits) and base64url encode the result
*/
declare
  base64url text;
begin
  base64url := replace(replace(encode(bytes, 'base64'), '+', '-'), '/', '_');
  -- Remove any padding characters at the end of the base64url-encoded value
  return substring(base64url from 1 for length(base64url) - length(base64url) % 4);
end;
$$ language plpgsql;

create function api.passkey_register_request() returns json as $$
/*
TODO: swagger docs
  API route /rpc/passkey_register_request
  Responds with required information to call navigator.credential.create() on the client
*/
declare usr record;
begin
  select id, user_name from data.user
  where id = request.user_id()
  into usr;

  if usr is NULL then
    raise "insufficient_privilege";
  else
    -- send info to openresty
    perform set_config('response.headers',
      '[{"X-Postgrest": "challenge=xyz"}]', true);
    return json_build_object(
      'rp', json_build_object(
        -- TODO: fetch values from env
        'name', 'receptdatabasen',
        'id', 'localhost'
      ),
      'user', json_build_object(
        'id', api.base64url(int4send(usr.id)),
        'name', usr.user_name,
        'displayName', usr.user_name
      ),
      'challenge', api.base64url(gen_random_bytes(12)),
      'pubKeyCredParams', jsonb_build_array(
        json_build_object(
          'type', 'public-key',
          'alg', -7
        ),
        json_build_object(
          'type', 'public-key',
          'alg', -257
        )
      ),
      'timeout', 1800000,
      'attestation', 'none',
      -- TODO: list of existing credentials
      'excludeCredentials', json_build_array(),
      'authenticatorSelection', jsonb_build_object(
        'authenticatorAttachment', 'platform',
        'userVerification', 'required'
      )
    );
  end if;
end
$$ security definer language plpgsql;

revoke all privileges on function api.passkey_register_request() from public;

/*
  Register user credential.
  Call this with the header `Prefer: params=single-object`
  Input format taken as single json object:
  ```{
     id: String,
     type: 'public-key',
     rawId: String,
     response: {
       clientDataJSON: String,
       attestationObject: String,
       signature: String,
       userHandle: String
     }
  }```
*/

create or replace function api.python_fn(raw_credential json) returns text as $$
  from webauthn import (
      verify_registration_response,
      base64url_to_bytes
  )
  from webauthn.helpers.structs import RegistrationCredential

  credential = RegistrationCredential.parse_raw(raw_credential)

  registration_verification = verify_registration_response(
      credential=credential,
      expected_challenge=base64url_to_bytes(
          "bFZ_Pd0RrLdUBXWE" # TODO read from session
      ),
      expected_origin="http://localhost:1234", # TODO read from env
      expected_rp_id="localhost", # TODO read from env
      require_user_verification=True
  )
  plpy.info(registration_verification)
  return registration_verification.json()
$$
language 'plpython3u';

create or replace function api.passkey_register_response(param json) returns json as $$
/*
TODO: swagger docs
  API route /rpc/passkey_register_request
  Responds with required information to call navigator.credential.create() on the client
*/
declare usr record;
declare t json;
begin
  select id, user_name from data.user
  where id = request.user_id()
  into usr;
  select api.python_fn(param::json) into t;

  if usr is NULL then
    raise "insufficient_privilege";
  else
    return t;
  end if;
end
$$ security definer language plpgsql;
revoke all privileges on function api.passkey_register_response(json) from public;
