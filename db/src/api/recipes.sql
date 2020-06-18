create or replace view api.recipes as (
  select
    id,
    title,
    description,
    instructions,
    tags,
    portions,
    ingredients,
    image,
    search,
    created_at,
    updated_at
  from data.recipe
);

alter view recipes owner to api; -- it is important to set the correct owner to the RLS policy kicks in

create trigger insert_recipe
instead of insert on api.recipes
for each row execute procedure util.insert_recipe();

create trigger update_recipe
instead of update on api.recipes
for each row execute procedure util.update_recipe();

