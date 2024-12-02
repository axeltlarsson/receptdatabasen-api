--- Module for interacting with the recipe database.
-- This module fetches recipe details and user information.
local cjson = require "cjson"
local utils = require "utils"

local M = {}

--- Fetch the ingredients of a recipe by its slug.
-- @param recipe_slug string The slug of the recipe to fetch.
-- @return table The recipe details as a Lua table.
-- @raise Error if the recipe cannot be found.
function M.get_recipe_ingredients(recipe_slug)
    local res = ngx.location.capture(
        "/internal/rest/recipes/" .. recipe_slug .. "?select=id,title,ingredients",
        { method = ngx.HTTP_GET }
    )

    if res.status ~= 200 then
        utils.return_error("Failed to fetch recipe", res.status)
    end

    return cjson.decode(res.body)
end

--- Fetch the user details from the `/me` endpoint.
-- @return string The user name of the authenticated user.
-- @raise Error if the user cannot be identified.
function M.get_user_name()
    local res = ngx.location.capture("/internal/rest/rpc/me", { method = ngx.HTTP_GET })

    if res.status ~= 200 then
        utils.return_error("Could not fetch user details", res.status)
    end

    return cjson.decode(res.body).user_name
end

return M
