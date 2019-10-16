CREATE SCHEMA data;

CREATE TABLE data.recipes(
  id            SERIAL PRIMARY KEY,
  title         TEXT NOT NULL UNIQUE CHECK (length(title) >= 3 AND length(title) <= 100),
  description   TEXT CHECK (description = NULL OR length(description) <= 500),
  instructions  TEXT NOT NULL CHECK (length(instructions) >= 5 AND length(instructions) <= 4000),
  tags          TEXT[] DEFAULT '{}',
  portions      INTEGER CHECK (portions > 0 and portions <= 100),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  textsearch    TSVECTOR GENERATED ALWAYS AS (
    to_tsvector('swedish', title || ' ' || coalesce(description, '') || ' ' || instructions)
    || array_to_tsvector(tags) -- TODO: this is not configured for Swedish and is not properly preprocessed
  ) STORED
);

CREATE INDEX recipes_title ON data.recipes (title);
CREATE INDEX recipes_textsearch_idx ON data.recipes USING GIN (textsearch);

CREATE OR REPLACE FUNCTION set_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- TODO: update if ingredients change - the recipes table ts should also change
CREATE TRIGGER set_updated_at_timestamp
BEFORE UPDATE ON data.recipes
FOR EACH ROW
EXECUTE PROCEDURE set_updated_at_timestamp();

CREATE TABLE data.ingredient_groups(
  id        SERIAL PRIMARY KEY,
  recipe_id INTEGER NOT NULL REFERENCES data.recipes ON DELETE CASCADE,
  name      TEXT NOT NULL,
  UNIQUE(id, recipe_id, name)
);
CREATE INDEX ingredient_groups_recipe_id ON data.ingredient_groups (recipe_id);

CREATE TABLE data.ingredients(
  id                  SERIAL PRIMARY KEY,
  ingredient_group_id INTEGER NOT NULL REFERENCES data.ingredient_groups ON DELETE CASCADE,
  contents            TEXT NOT NULL
);
CREATE INDEX ingredients_ingredient_group_id ON data.ingredients (ingredient_group_id);

CREATE SCHEMA api;

CREATE OR REPLACE VIEW api.recipes AS (
  SELECT
    id,
    title,
    description, 
    instructions,
    tags,
    portions,
    created_at,
    updated_at,
    textsearch AS search,
    (
      SELECT
        json_object_agg(name, ingredients)
      FROM (
        SELECT
          name,
          array_to_json(array_agg(ingredients.contents)) AS ingredients
        FROM data.ingredient_groups AS ingredient_groups
        LEFT JOIN data.ingredients AS ingredients ON ingredient_groups.id = ingredients.ingredient_group_id
        WHERE data.recipes.id = ingredient_groups.recipe_id
        GROUP BY recipe_id, name
        ORDER BY recipe_id, name
      ) groups
    ) AS ingredients
  FROM data.recipes
);

/*
 ingredients: {
  group1: [ingredients...],
  group2: [ingredients...]
 }
 */
CREATE FUNCTION api.insert_recipe()
RETURNS TRIGGER
AS $$
  DECLARE recipe_id int;
  DECLARE recipe_created_at timestamptz;
  DECLARE recipe_updated_at timestamptz;
  DECLARE g text;
  DECLARE ingredients json;
  DECLARE ingredient_group_id int;
  DECLARE ingredient text;

  BEGIN
    -- Insert the recipe
    INSERT INTO data.recipes (title, description, instructions, tags, portions)
            VALUES (new.title, new.description, new.instructions, new.tags, new.portions)
              RETURNING id, created_at, updated_at INTO recipe_id, recipe_created_at, recipe_updated_at;

    IF new.ingredients IS NULL OR new.ingredients::text = '{}'::text THEN
      RAISE EXCEPTION 'A recipe must have ingredients!';
    END IF;
    -- Insert the ingredient groups
    FOR g, ingredients IN SELECT * FROM json_each(new.ingredients) LOOP
      INSERT INTO data.ingredient_groups (name, recipe_id)
        VALUES (g, recipe_id)
        RETURNING id INTO ingredient_group_id;

        IF ingredients IS NULL OR json_array_length(ingredients) = 0 THEN
          RAISE EXCEPTION 'Ingredient group "%" must not be empty!', g;
        END IF;
      -- Insert the ingredients in each ingredient group
      FOR ingredient IN SELECT * FROM json_array_elements_text(ingredients) LOOP
        INSERT INTO data.ingredients (contents, ingredient_group_id)
        VALUES (ingredient, ingredient_group_id);
      END LOOP;

    END LOOP;

    new.id = recipe_id;
    new.created_at = recipe_created_at;
    new.updated_at = recipe_updated_at;
    RETURN new;
  END;
$$ LANGUAGE 'plpgsql';

CREATE FUNCTION api.update_recipe()
RETURNS TRIGGER
AS $$
  DECLARE recipe_id int;
  DECLARE recipe_created_at timestamptz;
  DECLARE recipe_updated_at timestamptz;
  DECLARE g text;
  DECLARE ingredients json;
  DECLARE ingredient_group_id int;
  DECLARE ingredient text;

  BEGIN
    -- update the recipe
    UPDATE data.recipes
    SET title = new.title, description = new.description, instructions = new.instructions,
        tags = new.tags, portions = new.portions
    WHERE id = new.id
      RETURNING id, created_at, updated_at INTO recipe_id, recipe_created_at, recipe_updated_at;

    IF new.ingredients IS NULL OR new.ingredients::text = '{}'::text THEN
      RAISE EXCEPTION 'A recipe must have ingredients!';
    END IF;

    -- Delete all ingredient_groups (cascades to ingredients)
    DELETE FROM data.ingredient_groups WHERE data.ingredient_groups.recipe_id = new.id;
    -- Insert the new ingredient groups
    FOR g, ingredients IN SELECT * FROM json_each(new.ingredients) LOOP
      INSERT INTO data.ingredient_groups (name, recipe_id)
        VALUES (g, recipe_id)
        RETURNING id INTO ingredient_group_id;

        IF ingredients IS NULL OR json_array_length(ingredients) = 0 THEN
          RAISE EXCEPTION 'Ingredient group "%" must not be empty!', g;
        END IF;
      -- Insert the ingredients in each ingredient group
      FOR ingredient IN SELECT * FROM json_array_elements_text(ingredients) LOOP
        INSERT INTO data.ingredients (contents, ingredient_group_id)
        VALUES (ingredient, ingredient_group_id);
      END LOOP;

    END LOOP;

    new.id = recipe_id;
    new.created_at = recipe_created_at;
    new.updated_at = recipe_updated_at;
    RETURN new;
  END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER insert_recipe
INSTEAD OF INSERT ON api.recipes
FOR EACH ROW EXECUTE PROCEDURE api.insert_recipe();

CREATE TRIGGER update_recipe
INSTEAD OF UPDATE ON api.recipes
FOR EACH ROW EXECUTE PROCEDURE api.update_recipe();
