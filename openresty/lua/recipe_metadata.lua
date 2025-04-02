-- recipe_metadata.lua
local cjson = require "cjson"
local utils = require "utils"
local _M = {}

--- This function is used to fetch recipe data from the API
--- @param title string The title of the recipe to fetch
--- @param secret string The secret key used to sign the image URLs
--- @return table|nil recipe_data as a Lua table, or nil on failure
function _M.get_by_title(title, secret)
    ngx.log(ngx.INFO, "Fetching recipe data for: " .. title)

    -- Make an internal API request to get the recipe data using the new function
    local res = ngx.location.capture(
        "/internal/rest/rpc/recipe_preview_by_title",
        {
            method = ngx.HTTP_POST,
            headers = {
                ["Content-Type"] = "application/json; charset=utf-8",
                ["Accept"] = "application/vnd.pgrst.object+json",
                ["Prefer"] = "return=representation"
            },
            body = cjson.encode({ recipe_title = title })
        }
    )

    if res.status ~= 200 then
        ngx.log(ngx.ERR, "Failed to fetch recipe: " .. res.status .. " " .. res.body)
        return nil, "API request failed with status " .. res.status
    end

    local recipe = cjson.decode(res.body)

    if not recipe or not recipe.id then
        ngx.log(ngx.ERR, "Recipe not found: " .. title)
        return nil, "Recipe not found"
    end

    -- Process description (truncate if needed)
    if recipe.description and recipe.description ~= cjson.null and #recipe.description > 160 then
        recipe.description = recipe.description:sub(1, 157) .. "..."
    end

    -- Prepend public-facing base url to image url
    if recipe.image_url ~= cjson.null then
        recipe.image_url = utils.get_base_url() .. recipe.image_url
    end

    -- Set the canonical URL
    recipe.canonical_url = utils.get_base_url() .. "/recipe/" .. ngx.escape_uri(recipe.title)

    return recipe
end

-- Function to get fallback metadata
function _M.get_fallback()
    return {
        title = "Receptdatabasen",
        description = "Din samling av favoritrecept",
        image_url = "",
        canonical_url = utils.get_base_url() .. ngx.var.uri
    }
end

return _M
