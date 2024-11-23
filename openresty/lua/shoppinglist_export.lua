local utils = require "utils"
local resty_session = require "resty.session"

-- Extract the recipe ID using ngx.re.match
local recipe_id_match = ngx.re.match(ngx.var.uri, "^/export_to_list/(\\w+)$")
local recipe_slug = recipe_id_match and recipe_id_match[1]

-- Proxy to PostgREST and fetch the recipe's ingredients
local recipe = ngx.location.capture(
    "/internal/rest/recipes/" .. recipe_slug .. "?select=id,title,ingredients",
    { method = ngx.HTTP_GET }
)

-- if we for some reason can't find the recipe, return the error
if recipe.status ~= 200 then
    ngx.status = recipe.status
    return ngx.say(recipe.body)
end


-- This should only ever be called with a valid session already in place, let's fetch the session
local session, err, exists, refreshed = resty_session.start()
if not exists or not session:get("jwt") then
    -- Shoul never happen since we require a valid session to access this endpoint
    utils.return_error("You need a valid session to access this endpoint", ngx.HTTP_UNAUTHORIZED)
end

-- debug print the session
print(session:get("jwt"))

-- make an HTTP request to the listan API in order to add the ingredients to the list
-- how to know which list to add the ingredients to?
-- how to know which user is making the request?
-- given that we would know the user from the session, we could use the user's ID to fetch the list ID

-- Return the response from PostgREST as is for now
ngx.status = recipe.status
ngx.say(recipe.body)
