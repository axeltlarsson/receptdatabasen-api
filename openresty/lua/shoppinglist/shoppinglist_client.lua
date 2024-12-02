--- Module for interacting with the shopping list API.
local cjson = require "cjson"
local http = require "resty.http"

local M = {}

--- Send ingredients to the shopping list API.
-- @param api_url string The API URL for the shopping list.
-- @param jwt_token string The JWT token used for authentication.
-- @param ingredients table A table containing the ingredients to add.
-- @return table The response from the shopping list API as a Lua table.
-- @raise Error if the HTTP request fails.
function M.send_ingredients(api_url, jwt_token, ingredients)
    local httpc = http.new()
    httpc:set_timeout(5000)

    local res, err = httpc:request_uri(api_url, {
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. jwt_token
        },
        body = cjson.encode(ingredients)
    })

    if not res then
        error("Failed to make request to shopping list API: " .. err)
    end

    if res.status ~= 200 then
        error("Shopping list API error: " .. res.body)
    end

    return cjson.decode(res.body)
end

return M
