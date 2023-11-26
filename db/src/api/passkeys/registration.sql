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

  return options_to_json(registration_options)

$$
language 'plpython3u';
revoke all privileges on function api.generate_registration_options(text, text, text, text[]) from public;

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
grant execute on function api.passkey_registration_begin() to webuser;

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
Call this with the header `Prefer: params=single-object`
*/
create or replace function api.passkey_registration_complete(param json) returns json as $$
-- param->>'expected_challenge" can be trusted as it's injected into the body from the session cookie by openresty
-- passkeys/registration_complete.lua
declare usr record;
declare registration json;

begin
  select id, user_name from data.user
  where id = request.user_id()
  into usr;

  if usr is NULL then
    raise "insufficient_privilege";
  else
    select api.verify_registration_response(param::json->>'raw_credential', param::json->>'expected_challenge') into registration;
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
grant execute on function api.passkey_registration_complete(json) to webuser;
