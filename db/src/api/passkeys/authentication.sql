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
  plpy.info(options_to_json(auth_options))

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
    raise "insufficient_privilege";
  else
    select api.generate_authentication_options(usr.user_name) into options;
    if options IS NULL then
      raise "insufficient_privilege";
    else
      return options;
    end if;
  end if;
end
$$ security definer language plpgsql;
revoke all privileges on function api.passkey_authentication_begin(json) from public;
--  unauthenticated users need to be able to execute this thus we grant execute also to anonymous
grant execute on function api.passkey_authentication_begin(json) to webuser, anonymous;
