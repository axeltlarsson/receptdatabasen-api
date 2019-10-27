CREATE SCHEMA data;

--  https://stackoverflow.com/questions/31210790/indexing-an-array-for-full-text-search
CREATE OR REPLACE FUNCTION data.immutable_array_to_string(text[])
  RETURNS text LANGUAGE sql IMMUTABLE AS 'SELECT $1::text';

CREATE TABLE data.recipes(
  id            SERIAL PRIMARY KEY,
  title         TEXT NOT NULL UNIQUE CHECK (length(title) >= 3 AND length(title) <= 100),
  description   TEXT CHECK (description = NULL OR length(description) <= 500),
  instructions  TEXT NOT NULL CHECK (length(instructions) >= 5 AND length(instructions) <= 4000),
  tags          TEXT[] DEFAULT '{}',
  portions      INTEGER CHECK (portions > 0 and portions <= 100),
  ingredients   JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  search        TSVECTOR GENERATED ALWAYS AS (
    to_tsvector('swedish', title || ' ' || coalesce(description, '') || ' ' || instructions)
    || to_tsvector('swedish', immutable_array_to_string(tags))
    || jsonb_to_tsvector('swedish', ingredients, '["all"]')
  ) STORED
);

CREATE INDEX recipes_title ON data.recipes (title);
CREATE INDEX recipes_search_idx ON data.recipes USING GIN (search);

CREATE OR REPLACE FUNCTION set_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_timestamp
BEFORE UPDATE ON data.recipes
FOR EACH ROW
EXECUTE PROCEDURE set_updated_at_timestamp();


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
    search,
    ingredients
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
    -- Validate ingredients json input
    IF new.ingredients IS NULL OR new.ingredients::text = '{}'::text THEN
      RAISE EXCEPTION 'A recipe must have ingredients!';
    END IF;
    FOR g, ingredients IN SELECT * FROM jsonb_each(new.ingredients) LOOP
        IF ingredients IS NULL OR json_array_length(ingredients) = 0 THEN
          RAISE EXCEPTION 'Ingredient group "%" must not be empty!', g;
        END IF;
    END LOOP;

    -- Insert the recipe
    INSERT INTO data.recipes (title, description, instructions, tags, portions, ingredients)
           VALUES (new.title, new.description, new.instructions, new.tags, new.portions, new.ingredients)
           RETURNING id, created_at, updated_at INTO recipe_id, recipe_created_at, recipe_updated_at;

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
    -- Validate ingredients json input
    IF new.ingredients IS NULL OR new.ingredients::text = '{}'::text THEN
      RAISE EXCEPTION 'A recipe must have ingredients!';
    END IF;
    FOR g, ingredients IN SELECT * FROM jsonb_each(new.ingredients) LOOP
        IF ingredients IS NULL OR json_array_length(ingredients) = 0 THEN
          RAISE EXCEPTION 'Ingredient group "%" must not be empty!', g;
        END IF;
    END LOOP;

    -- Update the recipe
    UPDATE data.recipes
    SET title = new.title, description = new.description, instructions = new.instructions,
        tags = new.tags, portions = new.portions, ingredients = new.ingredients
    WHERE id = new.id
      RETURNING id, created_at, updated_at INTO recipe_id, recipe_created_at, recipe_updated_at;

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

/*
 * Search function
 * Builds a prefix-matching search from a normal search query
 * Returns what the frontend calls a Recipe Preview of each matching recipe
 */
CREATE FUNCTION api.search(search_query text)
RETURNS 
  table(
    id integer,
    title text,
    description text,
    created_at timestamptz,
    updated_at timestamptz
  ) AS $$
WITH search AS (
  SELECT to_tsquery('swedish', string_agg(lexeme || ':*', ' & ' ORDER BY positions)) AS query
  FROM unnest(to_tsvector('swedish', search_query))
)
SELECT 
  id,
  title,
  description,
  created_at,
  updated_at
FROM api.recipes, search
WHERE api.recipes.search @@ search.query;
$$ LANGUAGE SQL IMMUTABLE;

