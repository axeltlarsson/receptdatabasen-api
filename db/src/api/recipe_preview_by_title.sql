-- For usage by the anonymous role (public access) for rich link previews
-- Only exposes specific fields needed for public access of rich link previews
create or replace function api.recipe_preview_by_title(recipe_title text)

returns table (
  id integer,
  title text,
  description text,
  image_url text
)
as $$
  select
    id,
    title,
    description,
    -- get the first, if any, url700 image url from the images array
    (images #>> '{0, url700}')::text as image_url
  from api.recipes
  where api.recipes.title = recipe_title
  limit 1;
$$ language sql
  stable
  security definer -- executes with permission of the function owner
  set search_path = api, pg_temp; -- set search path to the api schema for safety

-- Permissions:
-- since it's security definer, it executes with the permissions of the function owner
-- so we set the function owner to webuser and allow anonymous to execute it
alter function api.recipe_preview_by_title(text) owner to webuser;
revoke all privileges on function api.recipe_preview_by_title(text) from public;
grant usage on schema api to anonymous;
grant execute on function api.recipe_preview_by_title(text) to anonymous;
