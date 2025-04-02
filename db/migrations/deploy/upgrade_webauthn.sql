-- Deploy app:upgrade_webauthn to pg

BEGIN;

drop function api.generate_registration_options(text, text, text, text[]);
drop function api.verify_registration_response(text, text);
\ir ../../src/api/passkeys/registration.sql;
drop function api.verify_authentication_response(text, text, text, int);
\ir ../../src/api/passkeys/authentication.sql;

COMMIT;
