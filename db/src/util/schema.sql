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

  begin
    -- insert the recipe
    insert into data.recipe (title, description, instructions, tags, portions, ingredients, image)
           values (new.title, new.description, new.instructions, new.tags, new.portions, new.ingredients, new.image)
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

  begin
    -- update the recipe
    update data.recipe
    set title = new.title, description = new.description, instructions = new.instructions,
        tags = new.tags, portions = new.portions, ingredients = new.ingredients, image = new.image
    where id = new.id
      returning id, created_at, updated_at into recipe_id, recipe_created_at, recipe_updated_at;

    new.id = recipe_id;
    new.created_at = recipe_created_at;
    new.updated_at = recipe_updated_at;
    return new;
  end;
$$ security definer language plpgsql;
