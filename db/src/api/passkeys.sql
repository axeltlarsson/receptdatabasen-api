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
          HINT = 'Use /rpc/passkey_registration_begin and /rpc/passkey_registration_complete to add a new passkey';
END
$$;

create trigger forbid_passkey_insertion
instead of insert or update on api.passkeys
for each row execute procedure api.disabled();

/*
  passkeys/registration/begin
*/

create or replace function api.generate_registration_options(user_id text, user_name text, rp_id text) returns json as $$
  from webauthn import (
      generate_registration_options,
      options_to_json
  )

  registration_options = generate_registration_options(
    rp_id=rp_id,
    rp_name="receptdatabasen", 
    user_id=user_id,
    user_name=user_name,
    user_display_name=user_name,
  )
  plpy.info(options_to_json(registration_options))

  return options_to_json(registration_options)

$$
language 'plpython3u';

/*
API route /rpc/passkey_registration_begin
Responds with required information to call navigator.credential.create() on the client
*/
create function api.passkey_registration_begin() returns json as $$
declare usr record;
declare registration_options json;
begin
  select id, user_name from data.user
  where id = request.user_id()
  into usr;

  if usr is NULL then
    raise "insufficient_privilege";
  else
    select api.generate_registration_options(usr.id::text, usr.user_name, settings.get('rp_id')) into registration_options;
    return registration_options;
  end if;
end
$$ security definer language plpgsql;

revoke all privileges on function api.passkey_registration_begin() from public;


/*
  passkeys/registration/complete
*/
create or replace function api.verify_registration_response(raw_credential text, challenge text) returns text as $$
  from webauthn import (
      verify_registration_response,
      base64url_to_bytes
  )
  from webauthn.helpers.structs import RegistrationCredential
  from webauthn.helpers.exceptions import InvalidRegistrationResponse

  credential = RegistrationCredential.parse_raw(raw_credential)


  expected_origin = plpy.execute("select settings.get('origin')")[0]["get"]
  expected_rp_id = plpy.execute("select settings.get('rp_id')")[0]["get"]

  try:
    registration_verification = verify_registration_response(
        credential=credential,
        expected_challenge=base64url_to_bytes(challenge),
        expected_origin=expected_origin,
        expected_rp_id=expected_rp_id,
        require_user_verification=True
    )
  except InvalidRegistrationResponse as e:
    plpy.warning(e)
    return None

  return registration_verification.json()
$$
language 'plpython3u';

revoke all privileges on function api.verify_registration_response(text, text) from public;

/*
API route /rpc/passkey_registration_complete
TODO: Responds with verified user?
*/
create or replace function api.passkey_registration_complete(param json) returns json as $$
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
  Uses py_webauthn python lib to do the heavy lifting in api.generate_registration_options
*/
declare usr record;
declare t json;
begin
  select id, user_name from data.user
  where id = request.user_id()
  into usr;

  if usr is NULL then
    raise "insufficient_privilege";
  else
    select api.verify_registration_response(param::json->>'raw_credential', param::json->>'challenge') into t;
    if t IS NULL then
      raise "insufficient_privilege";
    else
      return t;
    end if;
  end if;
end
$$ security definer language plpgsql;
revoke all privileges on function api.passkey_registration_complete(json) from public;
