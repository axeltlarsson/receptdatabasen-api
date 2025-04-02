-- Revert app:sign_image_urls from pg

BEGIN;

 \ir ../../src/api/recipes.sql;

COMMIT;
