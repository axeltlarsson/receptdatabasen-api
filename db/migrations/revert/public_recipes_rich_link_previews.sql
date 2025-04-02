-- Revert app:public_recipes_rich_link_previews from pg

BEGIN;

drop function api.recipe_preview_by_title(text);

COMMIT;
