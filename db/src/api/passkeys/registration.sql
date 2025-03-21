/*
  passkeys/registration/begin
*/

create or replace function api.generate_registration_options(user_id text, user_name text, rp_id text, exclude_credentials text[]) returns json as $$

  from webauthn import (
      generate_registration_options,
      options_to_json,
      base64url_to_bytes,
  )
  from webauthn.helpers import generate_user_handle

  from webauthn.helpers.structs import (
    PublicKeyCredentialDescriptor,
    AuthenticatorSelectionCriteria,
    ResidentKeyRequirement,
    AuthenticatorAttachment
  )

  registration_options = generate_registration_options(
    rp_id=rp_id,
    rp_name="receptdatabasen", 
    # TODO: user_id should ideally be a random bytes id associated with each user record
    # https://github.com/duo-labs/py_webauthn/blob/master/CHANGELOG.md#option-2-generate-unique-webauthn-specific-identifiers-for-existing-and-new-users
    user_id=user_id.encode("utf-8"),
    user_name=user_name,
    user_display_name=user_name,
    exclude_credentials=[PublicKeyCredentialDescriptor(id=base64url_to_bytes(cred)) for cred in (exclude_credentials or [])],
    authenticator_selection=AuthenticatorSelectionCriteria(
        authenticator_attachment=AuthenticatorAttachment.PLATFORM,
        resident_key=ResidentKeyRequirement.REQUIRED,
    ),
  )

  return options_to_json(registration_options)

$$
language 'plpython3u';
revoke all privileges on function api.generate_registration_options(text, text, text, text[]) from public;

/*
API route /rpc/passkey_registration_begin
Responds with required information to call navigator.credential.create() on the client
*/
create or replace function api.passkey_registration_begin() returns json as $$
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
  from webauthn.helpers.structs import RegistrationCredential, AuthenticatorAttestationResponse
  from webauthn.helpers.exceptions import InvalidRegistrationResponse
  import json
  import dataclasses
  import base64

  expected_origin = plpy.execute("select settings.get('origin')")[0]["get"]
  expected_rp_id = plpy.execute("select settings.get('rp_id')")[0]["get"]
  disable_user_verification = plpy.execute("select settings.get('disable_user_verification')::bool")[0]["get"]
  require_user_verification = not bool(disable_user_verification)

  try:
    registration_verification = verify_registration_response(
          credential=raw_credential,
          expected_challenge=base64url_to_bytes(challenge),
          expected_origin=expected_origin,
          expected_rp_id=expected_rp_id,
          require_user_verification=require_user_verification
      )
  except InvalidRegistrationResponse as e:
    plpy.warning(e)
    return None


  # webauthn does not provide a way to easily serialise the VerifiedRegistration object
  # - it contains some bytes fields that we need to encode as base64
  class ByteToBase64Encoder(json.JSONEncoder):
        def default(self, obj):
            if isinstance(obj, bytes):
                # encode bytes as base64 string
                return base64.urlsafe_b64encode(obj).decode("utf-8").rstrip("=")
            return super().default(obj)

  return json.dumps(dataclasses.asdict(registration_verification), cls=ByteToBase64Encoder)
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

  if param::json->>'name' is null then
    raise exception 
      using detail = 'A name for the passkey is required',
      hint = 'Check your payload';
  end if;

  if usr is NULL then
    raise "insufficient_privilege";
  else
    select api.verify_registration_response(param::json->>'raw_credential', param::json->>'expected_challenge') into registration;
    if registration IS NULL then
      raise "insufficient_privilege";
    else
      insert into data.passkey (user_id, data, name) values (usr.id, registration, param::json->>'name'); 
      return registration;
    end if;
  end if;
end
$$ security definer language plpgsql;
revoke all privileges on function api.passkey_registration_complete(json) from public;
grant execute on function api.passkey_registration_complete(json) to webuser;
