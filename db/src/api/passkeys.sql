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
          HINT = 'Use /rpc/passkeyRegisterRequest and /rpc/passkeyRegisterResponse to add a new passkey';
END
$$;

create trigger forbid_passkey_insertion
instead of insert or update on api.passkeys
for each row execute procedure api.disabled();


create function api.passkeyRegisterRequest() returns json as $$
declare usr record;
begin
  select id, user_name from data.user
  where id = request.user_id()
  into usr;

  if usr is NULL then
    raise "insufficient_privilege";
  else
    return json_build_object(
      'rp', json_build_object(
        'name', 'receptdatabasen',
        'id', 'localhost'
      ),
      'user', json_build_object(
        'id', usr.id,
        'name', usr.user_name
      ),
      'challenge', 'xxx',
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
      'excludeCredentials', json_build_array(),
      'authenticatorSelection', jsonb_build_object(
        'authenticatorAttachment', 'platform',
        'userVerification', 'required'
      )
    );
  end if;
end
$$ security definer language plpgsql;

revoke all privileges on function api.passkeyRegisterRequest() from public;
