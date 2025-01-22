-- some settings to make the output less verbose
\set QUIET on
\set ON_ERROR_STOP on
set client_min_messages to warning;

-- load some variables from the env
\set db_dir `echo $DB_DIR`
\set anonymous `echo $DB_ANON_ROLE`
\set authenticator `echo $DB_USER`
\set authenticator_pass `echo $DB_PASS`
\set jwt_secret `echo $JWT_SECRET`
\set quoted_jwt_secret '\'' :jwt_secret '\''
\set jwt_lifetime `echo $JWT_LIFETIME`
\set quoted_jwt_lifetime '\'' :jwt_lifetime '\''
\set rp_id `echo $RP_ID`
\set origin `echo $ORIGIN`
\set disable_user_verification `echo $DISABLE_USER_VERIFICATION`

\echo # Loading database definition
begin;
create extension if not exists pgcrypto;
create extension if not exists plpython3u;

\echo # Loading dependencies
\echo db_dir: :db_dir

-- functions for storing different settings in a table
\ir :db_dir/libs/settings.sql

-- functions for reading different http request properties exposed by PostgREST
\ir :db_dir/libs/request.sql

-- functions for sending messages to RabbitMQ entities
\ir :db_dir/libs/rabbitmq.sql

-- functions for JWT token generation in the database context
\ir :db_dir/libs/pgjwt.sql

-- save app settings (they are stored in the settings.secrets table)
select settings.set('jwt_secret', :quoted_jwt_secret);
select settings.set('jwt_lifetime', :quoted_jwt_lifetime);
select settings.set('rp_id', :rp_id);
select settings.set('origin', :origin);
select settings.set('disable_user_verification', :disable_user_verification::int::text); --  settings need bools as '0' or '1'

\echo # Loading application definitions

\echo # Loading roles
\ir :db_dir/authorization/roles.sql

-- private schema where all tables will be defined
-- you can use other names besides "data" or even spread the tables
-- between different schemas. The schema name "data" is just a convention
\ir :db_dir/data/schema.sql

-- entities inside this schema (which should be only views and stored procedures) will be
-- exposed as API endpoints. Access to them however is still governed by the
-- privileges defined for the current PostgreSQL role making the requests
\ir :db_dir/api/schema.sql

\echo # Loading privileges
\ir :db_dir/authorization/privileges.sql

\echo # Loading sample data
\ir :db_dir/sample_data/data.sql


-- Deploy app:schema_cache_refresh_trigger to pg
-- Create an event trigger function - this will trigger postgrest schema cache reload
CREATE OR REPLACE FUNCTION pgrst_watch() RETURNS event_trigger
  LANGUAGE plpgsql
  AS $$
BEGIN
  NOTIFY pgrst, 'reload schema';
END;
$$;

-- This event trigger will fire after every ddl_command_end event
CREATE EVENT TRIGGER pgrst_watch
  ON ddl_command_end
  EXECUTE PROCEDURE pgrst_watch();


commit;
\echo # ==========================================
