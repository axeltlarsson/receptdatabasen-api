-- recipe_metadata.lua
local cjson = require "cjson"

local _M = {}

-- Function to get recipe data by title
-- @param title string The title of the recipe to fetch
-- @return table|nil, string The recipe data as a Lua table, or nil and an error message on failure
function _M.get_by_title(title)
    -- URL encode the title for the API request
    local encoded_title = ngx.escape_uri(title)

    -- Log what we're doing
    ngx.log(ngx.INFO, "Fetching recipe data for: " .. title)

    -- Make an internal API request to get the recipe data
    local res = ngx.location.capture(
        "/internal/rest/public/public_recipes?title=eq." .. encoded_title .. "&select=id,title,description,images",
        { method = ngx.HTTP_GET }
    )

    if res.status ~= 200 then
        ngx.log(ngx.ERR, "Failed to fetch recipe: " .. res.status .. res.body)
        return nil, "API request failed with status " .. res.status
    end

    local recipes = cjson.decode(res.body)
    if #recipes == 0 then
        ngx.log(ngx.ERR, "Recipe not found: " .. title)
        return nil, "Recipe not found"
    end

    local recipe = recipes[1]

    -- Process description (truncate if needed)
    if recipe.description and #recipe.description > 160 then
        recipe.description = recipe.description:sub(1, 157) .. "..."
    end

    if recipe.images and #recipe.images > 0 and recipe.images[1].url then
        -- Extract the URL from the image object
        recipe.image_url = ngx.var.scheme .. "://" .. ngx.var.host .. "/public-images/600/" .. recipe.images[1].url
        ngx.log(ngx.INFO, "Set image URL to: " .. recipe.image_url)
    else
        recipe.image_url = ngx.var.scheme .. "://" .. ngx.var.host .. "/images/default-recipe.jpg"
        ngx.log(ngx.INFO, "Using default image URL: " .. recipe.image_url)
    end
    -- Set canonical URL
    recipe.canonical_url = ngx.var.scheme .. "://" .. ngx.var.host .. "/recipe/" .. ngx.escape_uri(recipe.title)

    return recipe
end

-- Function to get fallback metadata
function _M.get_fallback()
    return {
        title = "Receptdatabasen",
        description = "Din samling av favoritrecept",
        image_url = ngx.var.scheme .. "://" .. ngx.var.host .. "/images/default-recipe.jpg",
        canonical_url = ngx.var.scheme .. "://" .. ngx.var.host .. ngx.var.uri
    }
end

return _M
