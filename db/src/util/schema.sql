/*
 * TODO: these mutations seem weird to place here?
 */
drop schema if exists util cascade;
create schema util;
set search_path = util, public;


--  Mutation triggers for recipe
create function util.insert_recipe()
returns trigger
as $$
  declare recipe_id int;
  declare recipe_created_at timestamptz;
  declare recipe_updated_at timestamptz;
  declare g text;
  declare ingredients json;
  declare ingredient_group_id int;
  declare ingredient text;

  begin
    -- insert the recipe
    insert into data.recipe (title, description, instructions, tags, portions, ingredients)
           values (new.title, new.description, new.instructions, new.tags, new.portions, new.ingredients)
           returning id, created_at, updated_at into recipe_id, recipe_created_at, recipe_updated_at;

    new.id = recipe_id;
    new.created_at = recipe_created_at;
    new.updated_at = recipe_updated_at;
    return new;
  end;
$$ security definer language plpgsql;

create function util.update_recipe()
returns trigger
as $$
  declare recipe_id int;
  declare recipe_created_at timestamptz;
  declare recipe_updated_at timestamptz;
  declare g text;
  declare ingredients json;
  declare ingredient_group_id int;
  declare ingredient text;

  begin
    -- update the recipe
    update data.recipe
    set title = new.title, description = new.description, instructions = new.instructions,
        tags = new.tags, portions = new.portions, ingredients = new.ingredients
    where id = new.id
      returning id, created_at, updated_at into recipe_id, recipe_created_at, recipe_updated_at;

    new.id = recipe_id;
    new.created_at = recipe_created_at;
    new.updated_at = recipe_updated_at;
    return new;
  end;
$$ security definer language plpgsql;
