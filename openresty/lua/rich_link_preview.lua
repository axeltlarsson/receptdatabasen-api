-- rich_link_preview.lua
local template = require "resty.template"
local metadata = require "recipe_metadata"
local secret = os.getenv("IMAGE_SERVER_SECRET")

-- Add detailed logging for debugging
ngx.log(ngx.INFO, "Starting rich link preview for URI: " .. ngx.var.uri)

-- Check if this is a recipe page
local uri_parts = ngx.var.uri:match("/recipe/(.+)")
if not uri_parts then
    ngx.log(ngx.INFO, "Not a recipe URL, skipping template rendering")
    return
end

-- URL decode the recipe title from the path
local recipe_title = ngx.unescape_uri(uri_parts)

-- Get the document root path
local document_root = ngx.var.document_root or "/usr/local/openresty/nginx/html"

-- Read the HTML template file
local f, err = io.open(document_root .. "/index.html", "r")
if not f then
    ngx.log(ngx.ERR, "Cannot read index.html from: " .. document_root .. " - Error: " .. (err or "unknown"))
    return
end

local html = f:read("*all")
f:close()

-- Fetch recipe metadata
local recipe, err = metadata.get_by_title(recipe_title, secret)
if not recipe then
    ngx.log(ngx.WARN, "Could not fetch recipe data: " .. (err or "unknown error"))
    ngx.log(ngx.WARN, "Using fallback metadata")
    recipe = metadata.get_fallback()
end

-- Use template rendering to apply metadata
local ok, err = pcall(function()
    template.render_string(html, recipe)
end)

if not ok then
    ngx.log(ngx.ERR, "Template rendering failed: " .. err)
    -- Don't exit with error, let Nginx serve the regular SPA
    return
end

ngx.log(ngx.INFO, "Template rendering successful")

-- Skip further processing
ngx.exit(ngx.OK)
