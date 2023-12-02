/*
  passkeys/authentication/begin
*/
create or replace function api.generate_authentication_options(user_name text) returns text as $$
  from webauthn import (
      generate_authentication_options,
      base64url_to_bytes,
      options_to_json,
  )

  origin = plpy.execute("select settings.get('origin')")[0]["get"]
  rp_id = plpy.execute("select settings.get('rp_id')")[0]["get"]
  disable_user_verification = plpy.execute("select settings.get('disable_user_verification')::bool")[0]["get"]
  require_user_verification = not bool(disable_user_verification)

  auth_options = generate_authentication_options(
    rp_id=rp_id,
  )

  return options_to_json(auth_options)
$$
language 'plpython3u';

revoke all privileges on function api.generate_authentication_options(text) from public;

create or replace function api.passkey_authentication_begin(param json) returns json as $$
declare usr record;
declare options json;

begin
  select id, user_name from data.user
  where user_name = param->>'user_name'
  into usr;

  if usr is NULL then
    raise exception
      using detail = 'Cannot find provided user_name, if any, in database.',
      hint = 'Provide an existing user id in the body of the POST request: { "user_name": "valid_user" }';
  else
    select api.generate_authentication_options(usr.user_name) into options;
    if options IS NULL then
      raise insufficient_privilege;
    else
      return options;
    end if;
  end if;
end
$$ security definer language plpgsql;
revoke all privileges on function api.passkey_authentication_begin(json) from public;
--  unauthenticated users need to be able to execute this thus we grant execute also to anonymous
grant execute on function api.passkey_authentication_begin(json) to webuser, anonymous;


/*
  passkeys/authentication/complete
*/
create or replace function api.verify_authentication_response(raw_credential text, challenge text, public_key text) returns text as $$
  from webauthn import (
      verify_authentication_response,
      base64url_to_bytes
  )
  from webauthn.helpers.structs import AuthenticationCredential
  from webauthn.helpers.exceptions import InvalidAuthenticationResponse

  credential = AuthenticationCredential.parse_raw(raw_credential)


  expected_origin = plpy.execute("select settings.get('origin')")[0]["get"]
  expected_rp_id = plpy.execute("select settings.get('rp_id')")[0]["get"]
  disable_user_verification = plpy.execute("select settings.get('disable_user_verification')::bool")[0]["get"]
  require_user_verification = not bool(disable_user_verification)

  try:
    auth_verification = verify_authentication_response(
        credential=credential,
        expected_challenge=base64url_to_bytes(challenge),
        expected_origin=expected_origin,
        expected_rp_id=expected_rp_id,
        credential_public_key=base64url_to_bytes(public_key),
        credential_current_sign_count=0,
        require_user_verification=require_user_verification
    )
  except InvalidAuthenticationResponse as e:
    plpy.warning(e)
    return None

  return auth_verification.json()
$$
language 'plpython3u';

revoke all privileges on function api.verify_authentication_response(text, text, text) from public;


-- helper function to get user_handle from credential
create or replace function api.user_handle_from_credential(raw_credential text) returns text as $$
  from webauthn.helpers.structs import AuthenticationCredential

  try:
    credential = AuthenticationCredential.parse_raw(raw_credential)
    return credential.response.user_handle.decode("utf-8")
  except Exception:
    return None
$$
language 'plpython3u';

revoke all privileges on function api.user_handle_from_credential(text) from public;

-- helper function to get credential_id from credential
create or replace function api.id_from_credential(raw_credential text) returns text as $$
  from webauthn.helpers.structs import AuthenticationCredential

  try:
    credential = AuthenticationCredential.parse_raw(raw_credential)
    plpy.warning(credential)
    return credential.id
  except Exception:
    return None
$$
language 'plpython3u';

revoke all privileges on function api.id_from_credential(text) from public;

create or replace function api.passkey_authentication_complete(param json) returns json as $$
declare
    usr record;
    authentication json;
    user_handle text;
    public_key text;
    credential_id text;
begin
    select api.user_handle_from_credential(param->>'raw_credential') into user_handle;
    select api.id_from_credential(param->>'raw_credential') into credential_id;

    if user_handle is null then
      raise exception
        using detail = 'Cannot parse user_handle from credential payload.',
            hint = 'Check your payload';
    end if;

    if credential_id is null then
      raise exception
        using detail = 'Cannot parse credential_id from credential payload.',
            hint = 'Check your payload';
    end if;

    select * into usr
    from data.user
    where id = user_handle::int;

    if usr is null then
      raise insufficient_privilege
        using detail = ('Cannot find user with id:', user_handle),
            hint = 'Check your user_handle';
    end if;

    select data->>'credential_public_key' into public_key
    from data.passkey
    where
      user_id = usr.id
      and data.passkey.data->>'credential_id' = credential_id
    order by created_at desc
    limit 1;

    if public_key is null then
      raise exception 'Cannot find matching passkey for user_id and credential_id'
      using detail = ('User_id: ', usr.id, 'credential_id: ', credential_id),
      hint = 'Check your user_handle payload';
    end if;

    select api.verify_authentication_response(param->>'raw_credential', param->>'expected_challenge', public_key)
    into authentication;

    if authentication is null then
        raise insufficient_privilege
        using hint = 'Authentication of credential failed';
    else
        return json_build_object(
          'me', json_build_object(
            'id', usr.id,
            'user_name', usr.user_name,
            'email', usr.email
          ),
          'authentication', authentication,
          'token', pgjwt.sign(
            json_build_object(
              'role', usr.role,
              'user_id', usr.id,
              'exp', extract(epoch from now())::integer + settings.get('jwt_lifetime')::int
            ),
            settings.get('jwt_secret')
          )
        );
    end if;
end
$$ security definer language plpgsql;
--  unauthenticated users need to be able to execute this thus we grant execute also to anonymous
grant execute on function api.passkey_authentication_complete(json) to webuser, anonymous;

