-- Deploy app:public_recipes_rich_link_previews to pg

BEGIN;

\ir ../../src/api/public_recipes.sql;

alter view api.public_recipes owner to api;

-- And grant access to only this view
GRANT SELECT ON api.public_recipes TO anonymous;

COMMIT;
