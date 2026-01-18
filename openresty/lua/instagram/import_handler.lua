-- Instagram Import Handler
-- Main endpoint handler for /rest/instagram/parse

local cjson = require "cjson"
local utils = require "utils"
local fetcher = require "instagram.fetcher"
local image_downloader = require "instagram.image_downloader"

-- Read and parse JSON body
ngx.req.read_body()
local body = ngx.req.get_body_data()

if not body then
    utils.return_error("Request body is required", ngx.HTTP_BAD_REQUEST)
end

local ok, request = pcall(cjson.decode, body)
if not ok or not request then
    utils.return_error("Invalid JSON in request body", ngx.HTTP_BAD_REQUEST)
end

local url = request.url
if not url or url == "" then
    utils.return_error("Missing 'url' field in request", ngx.HTTP_BAD_REQUEST)
end

-- Fetch and parse Instagram post
local result, err = fetcher.fetch_and_parse(url)
if not result then
    utils.return_error(err or "Failed to fetch Instagram post", ngx.HTTP_BAD_REQUEST)
end

-- Download and save image if available
local image_result = nil
if result.og_data and result.og_data.image_url then
    local img, img_err = image_downloader.download_and_save(result.og_data.image_url)
    if img then
        image_result = img
    else
        ngx.log(ngx.WARN, "Failed to download image: " .. (img_err or "unknown"))
    end
end

-- Build response
local response = {
    source_url = result.source_url,
    og_title = result.og_data.title,
    og_description = result.og_data.description,
    og_image_url = result.og_data.image_url,

    -- Recipe extraction results
    recipe = {
        title = result.recipe.title,
        description = result.recipe.description,
        portions = result.recipe.portions,
        ingredients = result.recipe.ingredients,
        instructions = result.recipe.instructions,
        tags = result.recipe.tags,
        is_recipe = result.recipe.is_recipe,
        raw_description = result.recipe.raw_description,
    },

    -- Local image (if downloaded)
    image = image_result,
}

ngx.status = ngx.HTTP_OK
ngx.say(cjson.encode(response))
