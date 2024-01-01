-- Deploy app:discoverable_credential to pg

BEGIN;

\ir ../../src/api/passkeys/registration.sql;

COMMIT;
