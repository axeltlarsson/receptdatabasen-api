local utils = require "utils"
local jwt_helper = require "shoppinglist/jwt_helper"
local shoppinglist_client = require "shoppinglist/shoppinglist_client"
local cjson = require "cjson"

-- Extract ingredient json list from body
ngx.req.read_body()
local body = ngx.req.get_body_data()

-- Parse the JSON payload
local payload, err_payload = cjson.decode(body)
if not payload then
    return utils.return_error(err_payload, ngx.HTTP_BAD_REQUEST)
end

-- Validate the payload
if not payload.ingredients or type(payload.ingredients) ~= "table" or #payload.ingredients == 0 then
    return utils.return_error("Expected non-empty array in field `ingredients`", ngx.HTTP_BAD_REQUEST)
end

-- Fetch the user_name from /me
local res_me = ngx.location.capture("/internal/rest/rpc/me", { method = ngx.HTTP_GET })

if res_me.status ~= ngx.HTTP_OK then
    utils.return_error("Could not fetch user details", res_me.status)
end
local user_name = cjson.decode(res_me.body).user_name

ngx.log(ngx.INFO, "Adding ingredients for user: " .. user_name)

-- Generate a JWT token for authentication
local jwt_token = jwt_helper.generate(user_name, os.getenv("LISTAN_JWT_SECRET"))

-- Prepare the API URL and payload
local api_url = os.getenv("LISTAN_API_URL") .. "/lists/batch"

-- Send ingredients to the shopping list API and send ok response back
local ok, err = pcall(function()
    local response = shoppinglist_client.send_ingredients(api_url, jwt_token, payload.ingredients)
    ngx.status = ngx.HTTP_OK
    ngx.say(cjson.encode(response))
end)

if not ok and err then
    ngx.log(ngx.ERR, "Error: ", err)
    utils.return_error(err, ngx.HTTP_INTERNAL_SERVER_ERROR)
end
