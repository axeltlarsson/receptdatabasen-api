create or replace view api.passkeys as (
  select
    id,
    user_id,
    data,
    name,
    updated_at,
    created_at,
    last_used_at
  from data.passkey
);

alter view api.passkeys owner to api;

CREATE OR REPLACE FUNCTION api.disabled() RETURNS trigger
  LANGUAGE plpgsql
  AS $$
BEGIN
  RAISE EXCEPTION 'Uploading raw passkeys is not allowed'
    USING DETAIL = 'Passkeys need to be registered in a two step process - first to obtain the configuration/challenge for the client - then to register the passkey',
          HINT = 'Use /passkeys/registration/begin and /passkey/registration/complete to add a new passkey';
END
$$;

create trigger forbid_passkey_insertion
instead of insert or update on api.passkeys
for each row execute procedure api.disabled();

grant select, update, delete on api.passkeys to webuser;
