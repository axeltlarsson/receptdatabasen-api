-- Deploy app:public_recipes_rich_link_previews to pg

BEGIN;

\ir ../../src/api/recipe_preview_by_title.sql;

COMMIT;
