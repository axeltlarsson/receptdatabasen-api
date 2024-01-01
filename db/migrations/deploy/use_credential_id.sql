-- Deploy app:use_credential_id to pg

BEGIN;

SET search_path = data;
create index if not exists idx_passkey_credential_id on data.passkey((data->>'credential_id'));
\ir ../../src/api/passkeys/authentication.sql;
drop function if exists api.user_handle_from_credential(text);

COMMIT;
