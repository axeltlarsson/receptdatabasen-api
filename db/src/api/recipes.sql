create or replace function sign_image_urls(images jsonb) returns jsonb
as $$
    select
      coalesce(
        (
          select
            jsonb_agg(
              jsonb_build_object(
                'url', img->>'url',
                'url1600', utils.generate_signed_image_url('/images', img->>'url', 1600),
                'url1496', utils.generate_signed_image_url('/images', img->>'url', 1496),
                'url700', utils.generate_signed_image_url('/public-images', img->>'url', 700)
              )
            )
          from
            jsonb_array_elements(images) as img
        ),
        '[]'
      ) as signed_images;
$$ language sql stable;

create or replace view api.recipes as (
  select
    id,
    title,
    description,
    instructions,
    tags,
    portions,
    ingredients,
    sign_image_urls(images) as images,
    search,
    created_at,
    updated_at
  from data.recipe
);

alter view api.recipes owner to api; -- it is important to set the correct owner so the RLS policy kicks in

-- Mutations
create or replace function insert_recipe()
returns trigger
as $$
  declare recipe_id int;
  declare recipe_created_at timestamptz;
  declare recipe_updated_at timestamptz;
  declare signed_images jsonb;

  begin
    -- insert the recipe
    insert into data.recipe (title, description, instructions, tags, portions, ingredients, images)
           values (new.title, new.description, new.instructions, new.tags, new.portions, new.ingredients, new.images)
           returning id, created_at, updated_at into recipe_id, recipe_created_at, recipe_updated_at;

    new.id = recipe_id;
    new.created_at = recipe_created_at;
    new.updated_at = recipe_updated_at;
    -- The client only uploads plain urls, so we need to sign them on the fly and include in the response, but not save them in the db
    -- new is what Postgrest will return when the header Prefer: return=representation is set
    select sign_image_urls(new.images) into signed_images;
    new.images = signed_images;
    return new;
  end;
$$ security definer language plpgsql;

drop trigger if exists insert_recipe on api.recipes;
create trigger insert_recipe
instead of insert on api.recipes
for each row execute procedure insert_recipe();

create or replace function update_recipe()
returns trigger
as $$
  declare recipe_id int;
  declare recipe_created_at timestamptz;
  declare recipe_updated_at timestamptz;
  declare signed_images jsonb;

  begin
    -- update the recipe
    update data.recipe
    set title = new.title, description = new.description, instructions = new.instructions,
        tags = new.tags, portions = new.portions, ingredients = new.ingredients, images = new.images
    where id = new.id
      returning id, created_at, updated_at into recipe_id, recipe_created_at, recipe_updated_at;

    new.id = recipe_id;
    new.created_at = recipe_created_at;
    new.updated_at = recipe_updated_at;
    -- The client only uploads plain urls, so we need to sign them on the fly and include in the response, but not save them in the db
    -- new is what Postgrest will return when the header Prefer: return=representation is set
    select sign_image_urls(new.images) into signed_images;
    new.images = signed_images;
    return new;
  end;
$$ security definer language plpgsql;

drop trigger if exists update_recipe on api.recipes;
create trigger update_recipe
instead of update on api.recipes
for each row execute procedure update_recipe();
