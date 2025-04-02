-- Deploy app:public_recipes_rich_link_previews to pg

BEGIN;

\ir ../../src/api/recipe_preview_by_title.sql;

alter function api.recipe_preview_by_title(text) owner to webuser;
grant usage on schema utils to webuser;

COMMIT;
