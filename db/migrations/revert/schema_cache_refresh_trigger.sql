-- Revert app:schema_cache_refresh_trigger from pg

BEGIN;

DROP EVENT TRIGGER pgrst_watch;
DROP FUNCTION pgrst_watch();

COMMIT;
