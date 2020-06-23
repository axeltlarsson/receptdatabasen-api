## Convert mysql db to postgres

1. Create the destination Postgres instance, and attach it to the `receptdatabasen_back` network:
  ```
  docker run --name migrating_receptdatabasen -e POSTGRES_PASSWORD=pass -d --network receptdatabasen_back -P postgres
  ```
2. Inspect the network to find IP address of `migrating_receptdatabasen` and `receptdatabasen_db_1`, (pgloader has issues with host_names containing "_" it seems...):
```
  docker network inspect receptdatabasen_back
  ```
3. Inspect the source container and find the password, store connection URI:s in some env vars for easy usage:
  ```
  MY_SOURCE="mysql://recipes:<pass>@172.20.0.2/recipes"
  PG_DEST="postgresql://postgres:pass@172.20.0.5/postgres"
  ```
4. Run the migration:
  ```
  docker run --rm --name pgloader --network receptdatabasen_back dimitri/pgloader:latest pgloader $MY_SOURCE $PG_DEST
  ```
5. Verify by connecting to the destination:
```
  docker exec -it migrating_receptdatabasen psql -U postgres -d postgres
  \dt
  select * from Gallery limit 10;
  ```
6. Create a dump:
  ```
  docker exec -it migrating_receptdatabasen bash
  pg_dump recipes > dump.sql
  exit
  docker cp migrating_receptdatabasen:/dump.sql ./
  ```
7. Restore the dump into any pg you want, or use the already created pg instance to transform the tables appropriately.

## Convert database schema to the new one

```sql
with sets as (
  select
    sets.p_id as set_id,
    setname,
    sets.f_id as recipe_id,
    ingredients.f_id as ingredient_id,
    ingredients.ingredient
  from sets join ingredients on sets.p_id = ingredients.f_id
  order by set_id
  ), agg_sets as (

  select
  recipe_id,
  case lower(trim(setname))
  when 'ingredienser' then '- '
  else '## ' || trim(setname) || '
- ' end ||
  string_agg(ingredient, '
- ') as ingredients
  from sets
  group by recipe_id, setname, set_id
  order by recipe_id, set_id
),
ingredients_source as (
select
  recipe_id,
  string_agg(ingredients, '

') as ingredients
from agg_sets
group by recipe_id
),
source as (
  select
    title,
    intro as description,
    regexp_replace(instructions, E'[\\r]+', ' ', 'g' ) as instructions,
    nbrofpersons as portions,
    datecreated as created_at,
    dateupdated as updated_at,
    ingredients_source.ingredients,
    array_agg(tag) as tags
  from recipes.recipes
  left join recipes.tags on recipes.tags.f_id = recipes.recipes.p_id
  left join ingredients_source on ingredients_source.recipe_id = recipes.recipes.p_id
  group by 1,2,3,4,5,6,7


)
insert into data.recipe (title, description, instructions, portions, created_at, updated_at, ingredients, tags)
select * from source
;
```

## Dump the converted table

```shell
pg_dump --schema=data --data-only oldrecipes > converted_dump.sql
```

## Import into the running container

```shell
docker-compose exec -T db psql -U superuser -d app < converted_dump.sql
```
