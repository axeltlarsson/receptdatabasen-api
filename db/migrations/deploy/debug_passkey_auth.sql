-- Deploy app:debug_passkey_auth to pg

BEGIN;

SET search_path = data;
\ir ../../src/api/passkeys/authentication.sql;

COMMIT;
