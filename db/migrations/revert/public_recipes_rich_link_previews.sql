-- Revert app:public_recipes_rich_link_previews from pg

BEGIN;

drop view api.public_recipes;

COMMIT;
