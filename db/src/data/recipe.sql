--  https://stackoverflow.com/questions/31210790/indexing-an-array-for-full-text-search
create or replace function data.immutable_array_to_string(text[])
  returns text language sql immutable as 'select $1::text';

create table data.recipe(
  id            serial primary key,
  title         text not null unique constraint title_length check (length(title) >= 3 and length(title) <= 100),
  description   text constraint description_length check (description = null or length(description) <= 500),
  instructions  text not null constraint instructions_length check (length(instructions) >= 5 and length(instructions) <= 4000),
  tags          text[] not null default '{}',
  portions      integer not null constraint portions_size check (portions > 0 and portions <= 100),
  ingredients   jsonb not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  search        tsvector generated always as (
    setweight(to_tsvector('swedish', title), 'a')
    || setweight(to_tsvector('swedish', coalesce(description, '')), 'c')
    || setweight(to_tsvector('swedish', instructions), 'c')
    || setweight(to_tsvector('swedish', immutable_array_to_string(tags)), 'b')
    || setweight(jsonb_to_tsvector('swedish', ingredients, '["all"]'), 'd')
  ) stored
);

create index recipe_title on data.recipe (title);
create index recipe_search_idx on data.recipe using gin (search);

create or replace function set_updated_at_timestamp()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger set_updated_at_timestamp
before update on data.recipe
for each row
execute procedure set_updated_at_timestamp();

