drop schema if exists data cascade;
create schema data;
set search_path = data, public;

-- import our application models
\ir user.sql
\ir recipe.sql
\ir passkey.sql
