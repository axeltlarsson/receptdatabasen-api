drop schema if exists request cascade;
create schema request;
grant usage on schema request to public;

create or replace function request.jwt_claim(c text) returns text as $$
    select current_setting('request.jwt.claims', true)::json->>c;
$$ stable language sql;

create or replace function request.cookie(c text) returns text as $$
    select current_setting('request.cookies', true)::json->>c;
$$ stable language sql;

create or replace function request.header(h text) returns text as $$
    select current_setting('request.headers', true)::json->>h;
$$ stable language sql;

create or replace function request.user_id() returns int as $$
    select 
    case coalesce(request.jwt_claim('user_id'),'')
    when '' then 0
    else request.jwt_claim('user_id')::int
	end
$$ stable language sql;

create or replace function request.user_role() returns text as $$
    select request.jwt_claim('role')::text;
$$ stable language sql;
