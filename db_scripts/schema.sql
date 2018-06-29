CREATE SCHEMA data;

CREATE TABLE data.recipes(
  id            SERIAL PRIMARY KEY,
  title         TEXT NOT NULL UNIQUE,
  description   TEXT,
  instructions  TEXT NOT NULL,
  tags          TEXT[],
  quantity      INTEGER,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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

CREATE TABLE data.ingredients(
  id                  SERIAL PRIMARY KEY,
  ingredient_group_id INTEGER NOT NULL REFERENCES data.ingredient_groups ON DELETE CASCADE,
  contents            TEXT NOT NULL
);

CREATE SCHEMA api;

CREATE OR REPLACE VIEW api.recipes AS (
  SELECT
    rs.*,
    (
      SELECT
        json_object_agg(name, ingredients)
      FROM (
        SELECT
          name,
          array_to_json(array_agg(ingredients.contents)) AS ingredients
        FROM data.ingredient_groups AS ingredient_groups
        LEFT JOIN data.ingredients AS ingredients ON ingredient_groups.id = ingredients.ingredient_group_id
        WHERE rs.id = ingredient_groups.recipe_id
        GROUP BY recipe_id, name
        ORDER BY recipe_id, name
      ) groups
    ) AS ingredients
  FROM data.recipes AS rs
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
  DECLARE g text;
  DECLARE ingredients json;
  DECLARE ingredient_group_id int;
  DECLARE ingredient text;
  BEGIN
    -- Insert the recipe
    INSERT INTO data.recipes (title, description, instructions, tags, quantity)
            VALUES (new.title, new.description, new.instructions, new.tags, new.quantity) RETURNING id INTO recipe_id;
    -- Insert the ingredient groups
    FOR g, ingredients IN SELECT * FROM json_each(new.ingredients) LOOP
      INSERT INTO data.ingredient_groups (name, recipe_id) VALUES (g, recipe_id) RETURNING id INTO ingredient_group_id;

      -- Insert the ingredients in each ingredient group
      FOR ingredient IN SELECT * FROM json_array_elements_text(ingredients) LOOP
        INSERT INTO data.ingredients (contents, ingredient_group_id) VALUES (ingredient, ingredient_group_id);
      END LOOP;

    END LOOP;
    RETURN new;
  END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER insert_recipe
INSTEAD OF INSERT ON api.recipes
FOR EACH ROW
EXECUTE PROCEDURE api.insert_recipe();
