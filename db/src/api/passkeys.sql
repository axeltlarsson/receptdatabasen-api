create or replace view api.passkeys as (
  select
    id,
    user_id,
    data,
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

create or replace function api.generate_registration_options(user_id text, user_name text, rp_id text, exclude_credentials text[]) returns json as $$
  from webauthn import (
      generate_registration_options,
      options_to_json,
  )
  from webauthn.helpers.structs import PublicKeyCredentialDescriptor

  if exclude_credentials is None:
    exclude_creds = []
  else:
    exclude_creds = exclude_credentials

  registration_options = generate_registration_options(
    rp_id=rp_id,
    rp_name="receptdatabasen", 
    user_id=user_id,
    user_name=user_name,
    user_display_name=user_name,
    exclude_credentials=[PublicKeyCredentialDescriptor(id=bytes(cred, 'utf-8')) for cred in exclude_creds]
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
declare exclude_credentials text[] := ARRAY[]::text[];
begin
  select id, user_name from data.user
  where id = request.user_id()
  into usr;

  -- fetch existing passkeys for exclusion
  select array_agg(data->>'credential_id')
  from data.passkey
  where user_id = usr.id
  into exclude_credentials;

  if usr is NULL then
    raise "insufficient_privilege";
  else
    select api.generate_registration_options(usr.id::text, usr.user_name, settings.get('rp_id'), exclude_credentials) into registration_options;
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
  disable_user_verification = plpy.execute("select settings.get('disable_user_verification')::bool")[0]["get"]
  require_user_verification = not bool(disable_user_verification)

  try:
    registration_verification = verify_registration_response(
        credential=credential,
        expected_challenge=base64url_to_bytes(challenge),
        expected_origin=expected_origin,
        expected_rp_id=expected_rp_id,
        require_user_verification=require_user_verification
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
declare registration json;

begin
  select id, user_name from data.user
  where id = request.user_id()
  into usr;

  if usr is NULL then
    raise "insufficient_privilege";
  else
    select api.verify_registration_response(param::json->>'raw_credential', param::json->>'challenge') into registration;
    if registration IS NULL then
      raise "insufficient_privilege";
    else
      insert into data.passkey (user_id, data) values (usr.id, registration); 
      return registration;
    end if;
  end if;
end
$$ security definer language plpgsql;
revoke all privileges on function api.passkey_registration_complete(json) from public;
