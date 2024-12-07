--- Module for interacting with the shopping list API.
local cjson = require "cjson"
local http = require "resty.http"

local M = {}

--- Send ingredients to the shopping list API.
-- @param api_url string The API URL for the shopping list.
-- @param jwt_token string The JWT token used for authentication.
-- @param ingredients table A table containing the ingredients to add.
-- @return table, string|nil The response from the shopping list API as a Lua table, or nil and an error message on failure.
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
        return nil, "HTTP request to listan failed: " .. err
    end

    if res.status ~= 200 then
        return nil, "API request to listan failed: " .. res.status .. ' ' .. (res.body or "No response body")
    end

    local decoded, decode_err = cjson.decode(res.body)
    if not decoded then
        return nil, "Failed to decode response body from listan: " .. decode_err
    end

    return decoded, nil
end

return M
