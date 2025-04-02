-- Deploy app:sign_image_urls to pg

BEGIN;

    \ir ../../src/libs/utils.sql;
    \ir ../../src/api/recipes.sql;
    \ir ../../src/api/recipe_preview_by_title.sql;
    \ir ../../src/authorization/privileges.sql;

COMMIT;
