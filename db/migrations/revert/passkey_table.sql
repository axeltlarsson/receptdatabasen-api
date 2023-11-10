-- Revert app:passkey_table from pg

BEGIN;

  set search_path = data;
  drop view if exists api.passkeys;
  drop table if exists data.passkey;
  drop function api.disabled();
  drop function api.passkey_registration_begin();
  drop function api.passkey_registration_complete(json);
  drop function api.generate_registration_options(user_id text, user_name text, rp_id text);
  drop function api.verify_registration_response(raw_credential text, challenge text);

COMMIT;
