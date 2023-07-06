-- Revert app:passkey_table from pg

BEGIN;

  set search_path = data;
  drop view if exists api.passkeys;
  drop table if exists data.passkey;
  drop function api.passkey_register_request();
  drop function api.disabled();
  drop function api.base64url(bytea);

COMMIT;
