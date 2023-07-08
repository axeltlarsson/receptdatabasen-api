-- Deploy app:passkey_table to pg

BEGIN;

create extension if not exists plpython3u;
SET search_path = data;
\ir ../../src/data/passkey.sql;
\ir ../../src/api/passkeys.sql;
grant select, insert, update, delete on data.passkey to api;
grant select, insert, update, delete on api.passkeys to webuser;
grant execute on function api.passkey_register_request() to webuser;
grant execute on function api.passkey_register_response(json) to webuser;

COMMIT;

