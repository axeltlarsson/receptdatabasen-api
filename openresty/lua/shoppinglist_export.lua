local utils = require "utils"
local cjson = require "cjson"
local jwt = require "resty.jwt"

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


-- get the user information from /me
local user = ngx.location.capture(
    "/internal/rest/rpc/me",
    { method = ngx.HTTP_GET }
)

-- if we for some reason can't find the user, return the error
if user.status ~= 200 then
    utils.return_error("Could not find user", user.status)
end

-- extract the user ID from the response
local user_name = cjson.decode(user.body).user_name
print("Adding ingredients to list for user: " .. user_name)

-- prepare the payload for the http request
-- we need to create a jwt token to authenticate the request
local function generate_jwt(listan_user_name)
    local secret = os.getenv("LISTAN_JWT_SECRET") -- Shared secret between listan and receptdatabasen
    local token = jwt:sign(
        secret,
        {
            header = { typ = "JWT", alg = "HS256" },
            payload = {
                iss = "receptdatabasen",
                aud = "listan",
                sub = listan_user_name,
                scope = "add:ingredients",
                iat = ngx.now(),
                exp = ngx.now() + 600 -- Expires in 10 minutes
            }
        }
    )
    return token
end

local jwt_token = generate_jwt(user_name) -- assume same user_name in both services


-- make an HTTP request to the listan API in order to add the ingredients to the list
-- how to know which list to add the ingredients to? - we just assume the first available list for now
-- how to know which user is making the request? - we know from a call to /me to get the user_name
-- make the external http request to the listan API

local api_url = os.getenv("LISTAN_API_URL") .. "/lists/batch/"
print("POST to " .. api_url)


-- Return the response from PostgREST as is for now
ngx.status = recipe.status
ngx.say(cjson.encode({ jwt = jwt_token, recipe = cjson.decode(recipe.body) }))
