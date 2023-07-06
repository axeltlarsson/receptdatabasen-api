-- Deploy app:passkey_table to pg

BEGIN;

SET search_path = data;
\ir ../../src/data/passkey.sql;
\ir ../../src/api/passkeys.sql;
grant select, insert, update, delete on data.passkey to api;
grant select, insert, update, delete on api.passkeys to webuser;
grant execute on function api.passkey_register_request() to webuser;

COMMIT;

