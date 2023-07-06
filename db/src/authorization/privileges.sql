\echo # Loading roles privilege

-- this file contains the privileges of all aplications roles to each database entity
-- if it gets too long, you can split it one file per entity ore move the permissions
-- to the file where you defined the entity

-- specify which application roles can access this api (you'll probably list them all)
grant usage on schema api to anonymous, webuser;

-- set privileges to all the auth flow functions
grant execute on function api.login(text,text) to anonymous;
grant execute on function api.me() to webuser;
grant execute on function api.login(text,text) to webuser;
grant execute on function api.passkey_register_request() to webuser;

-- grants for the view owner of underlying data tables
grant select, insert, update, delete on data.recipe to api;
grant select, insert, update, delete on data.passkey to api;
grant usage on data.recipe_id_seq to webuser;


-- While grants to the view owner and the RLS policy on the underlying table
-- takes care of what rows the view can see, we still need to define what
-- are the rights of our application user in regard to this api view.

-- authenticated users can request/change all the columns for this view
grant select, insert, update, delete on api.recipes to webuser;
grant select, insert, update, delete on api.passkeys to webuser;

-------------------------------------------------------------------------------

grant execute on function api.search(text) to webuser;
