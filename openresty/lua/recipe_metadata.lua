-- recipe_metadata.lua
local cjson = require "cjson"
local utils = require "utils"
local _M = {}

-- This function is used to fetch recipe data from the API
-- @param title string The title of the recipe to fetch
-- @param secret string The secret key used to sign the image URLs
-- @return table|nil The recipe data as a Lua table, or nil on failure
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

    -- Get server port
    local server_port = ngx.var.server_port
    local port_suffix = ""
    if server_port ~= "80" and server_port ~= "443" then
        port_suffix = ":" .. server_port
    end

    -- Generate image URL if present
    if recipe.images and #recipe.images > 0 and recipe.images[1].url then
        -- Extract the URL from the image object
        local size = "700"
        local signature = utils.calculate_signature(secret, size .. "/" .. recipe.images[1].url)
        print("calculated signatuer with secret: " .. secret .. " and url: " .. recipe.images[1].url .. " to: " .. signature)
        recipe.image_url = ngx.var.scheme ..
            "://" .. ngx.var.host .. port_suffix .. "/public-images/" .. signature .. "/" .. size .. "/" .. recipe.images[1].url
        ngx.log(ngx.INFO, "Set image URL to: " .. recipe.image_url)
    else
        recipe.image_url = ""
    end

    -- Set canonical URL with port
    recipe.canonical_url = ngx.var.scheme ..
        "://" .. ngx.var.host .. port_suffix .. "/recipe/" .. ngx.escape_uri(recipe.title)

    return recipe
end

-- Function to get fallback metadata
function _M.get_fallback()
    -- Get server port
    local server_port = ngx.var.server_port
    local port_suffix = ""
    if server_port ~= "80" and server_port ~= "443" then
        port_suffix = ":" .. server_port
    end

    return {
        title = "Receptdatabasen",
        description = "Din samling av favoritrecept",
        image_url = "",
        canonical_url = ngx.var.scheme .. "://" .. ngx.var.host .. port_suffix .. ngx.var.uri
    }
end

return _M
