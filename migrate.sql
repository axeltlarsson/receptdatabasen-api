set search_path to data, recipes;

do $$
begin
  ASSERT (
    select
      count(*) > 1 from recipes);
end
$$;

truncate table data.recipe restart identity;

with sets as (
  select
    sets.p_id as set_id,
    setname,
    sets.f_id as recipe_id,
    ingredients.f_id as ingredient_id,
    ingredients.ingredient
  from
    sets
    join ingredients on sets.p_id = ingredients.f_id
  order by
    set_id
),
agg_sets as (
  select
    recipe_id,
    case lower(trim(setname))
    when 'ingredienser' then
      '- '
    else
      '#  ' || trim(setname) || '
- '
    end || string_agg(ingredient, '
- ') as ingredients
from
  sets
group by
  recipe_id,
  setname,
  set_id
order by
  recipe_id,
  set_id
),
ingredients_source as (
  select
    recipe_id,
    string_agg(ingredients, '

') as ingredients
from
  agg_sets
group by
  recipe_id
),
tags_source as (
  select
    f_id as recipe_id,
    array_agg(tag) as tags
from
  tags
group by
  f_id
),
source as (
  select
    title,
    nullif (intro, '') as description,
  regexp_replace(instructions, E'[\\r]+', ' ', 'g') as instructions,
  nbrofpersons as portions,
  datecreated as created_at,
  dateupdated as updated_at,
  ingredients_source.ingredients,
  coalesce(tags, '{}') as tags,
  array_to_json(array_remove(array_agg(jsonb_strip_nulls (jsonb_build_object('url', split_part(filepath, '/', 4), 'caption', case when caption <> '' then
              caption
            end))), '{}')) as images
from
  recipes.recipes
  left join tags_source on tags_source.recipe_id = recipes.recipes.p_id
    left join ingredients_source on ingredients_source.recipe_id = recipes.recipes.p_id
    left join gallery on gallery.f_id = recipes.recipes.p_id
  group by
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8)
  insert into data.recipe (title, description, instructions, portions, created_at, updated_at, ingredients, tags, images)
  select
    *
  from
    source
