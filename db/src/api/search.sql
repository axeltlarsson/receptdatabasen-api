/*
 * search function
 * builds a prefix-matching search from a normal search query
 * returns what the frontend calls a recipe preview of each matching recipe
 */
create function api.search(search_query text)
returns
  table(
    id integer,
    title text,
    description text,
    created_at timestamptz,
    updated_at timestamptz
  ) as $$
with search as (
  select to_tsquery('swedish', string_agg(lexeme || ':*', ' & ' order by positions)) as query
  from unnest(to_tsvector('swedish', search_query))
)
select
  id,
  title,
  description,
  created_at,
  updated_at
from api.recipes, search
where api.recipes.search @@ search.query
order by ts_rank_cd(api.recipes.search, search.query) desc
limit 10;
$$ language sql immutable;

-- by default all functions are accessible to the public, we need to remove that and define our specific access rules
revoke all privileges on function api.search(text) from public;
