-- Deploy app:fix_webauthn_user_handle to pg

BEGIN;

\ir ../../src/api/passkeys/registration.sql;

COMMIT;
