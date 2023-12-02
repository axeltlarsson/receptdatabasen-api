-- Deploy app:passkey_table to pg

BEGIN;

create extension if not exists plpython3u;
SET search_path = data;
\ir ../../src/data/passkey.sql;
\ir ../../src/api/passkeys/passkeys.sql;
\ir ../../src/api/passkeys/registration.sql;
\ir ../../src/api/passkeys/authentication.sql;
\ir ../../src/api/login.sql;

COMMIT;

