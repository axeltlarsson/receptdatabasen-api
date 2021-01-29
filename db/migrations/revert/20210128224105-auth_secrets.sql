-- Revert app:20210128224105-auth_secrets from pg

BEGIN;

select settings.set('jwt_lifetime', '6400'); 

COMMIT;
