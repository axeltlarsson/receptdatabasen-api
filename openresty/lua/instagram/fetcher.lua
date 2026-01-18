-- Instagram Fetcher Module
-- Fetches Instagram post HTML and extracts data using parser modules

local http = require "resty.http"
local parser = require "instagram.parser"
local recipe_extractor = require "instagram.recipe_extractor"

local M = {}

-- Validate that URL is an Instagram URL
local function is_valid_instagram_url(url)
    if not url or type(url) ~= "string" then
        return false
    end
    return url:match("^https?://[www%.]*instagram%.com/") ~= nil
end

-- Fetch HTML content from URL
local function fetch_html(url)
    local httpc = http.new()
    httpc:set_timeout(10000)  -- 10 second timeout

    local res, err = httpc:request_uri(url, {
        method = "GET",
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (compatible; RecipeBot/1.0)",
            ["Accept"] = "text/html",
        },
        ssl_verify = false,  -- Instagram uses HTTPS
    })

    if not res then
        return nil, "HTTP request failed: " .. (err or "unknown error")
    end

    if res.status ~= 200 then
        return nil, "HTTP request returned status " .. res.status
    end

    return res.body
end

--- Fetch and parse an Instagram post
--- @param url string The Instagram post URL
--- @return table|nil result The parsed result with og_data and recipe
--- @return string|nil error Error message if failed
function M.fetch_and_parse(url)
    -- Validate URL
    if not is_valid_instagram_url(url) then
        return nil, "Invalid Instagram URL"
    end

    -- Fetch HTML
    local html, err = fetch_html(url)
    if not html then
        return nil, err
    end

    -- Parse og:meta tags
    local og_data = parser.parse(html)
    if not og_data.description then
        return nil, "Could not find og:description in Instagram page"
    end

    -- Extract recipe data
    local recipe = recipe_extractor.extract(og_data.description)

    return {
        og_data = og_data,
        recipe = recipe,
        source_url = url,
    }
end

return M
