-- Deploy app:20210128224105-auth_secrets to pg

BEGIN;

SET search_path = settings, pg_catalog, public;

select settings.set('jwt_lifetime', '604860');

COMMIT;
