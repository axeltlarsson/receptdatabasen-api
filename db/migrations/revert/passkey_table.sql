-- Revert app:passkey_table from pg

BEGIN;

  set search_path = data;
  drop view if exists api.passkeys;
  drop table if exists data.passkey;
  drop function api.passkeyRegisterRequest();
  drop function api.disabled();

COMMIT;
