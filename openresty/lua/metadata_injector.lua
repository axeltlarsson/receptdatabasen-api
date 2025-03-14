-- simple_template.lua
local template = require "resty.template"

-- Check if this is a recipe page (just for structure, we'll handle all routes the same for now)
local uri_parts = ngx.var.uri:match("/recipe/(.+)")
if not uri_parts then
    -- Not a recipe URL, just continue to serve regular SPA
    return
end

-- Read the built HTML file
local document_root = ngx.var.document_root or "/usr/local/openresty/nginx/html"
local f = io.open(document_root .. "/index.html", "r")
if not f then
    ngx.log(ngx.ERR, "Cannot read index.html from: " .. document_root)
    return
end

local html = f:read("*all")
f:close()

-- Default values for testing
local context = {
    title = "Delicious Recipe Title",
    description =
    "This is a test description for our recipe preview card. It shows we can inject metadata into the template.",
    image = ngx.var.scheme .. "://" .. ngx.var.host .. "/assets/default-recipe-image.jpg",
    url = ngx.var.scheme .. "://" .. ngx.var.host .. ngx.var.uri,
}

ngx.log(ngx.INFO, "Injecting default values into template")

-- Render template with default values
template.render_string(html, context)

-- Skip further processing
ngx.exit(ngx.OK)
