-- Instagram HTML Parser Module
-- Extracts structured data from Instagram post HTML

local M = {}

local utf8 = require("lua-utf8")

-- HTML entity decoder
local function decode_html_entities(text)
    if not text then return nil end

    -- Decode numeric entities (&#xHH; and &#DDD;)
    text = text:gsub("&#x([%x]+);", function(hex)
        local codepoint = tonumber(hex, 16)
        return utf8.char(codepoint)
    end)
    text = text:gsub("&#(%d+);", function(dec)
        local codepoint = tonumber(dec)
        return utf8.char(codepoint)
    end)

    -- Common named entities
    local entities = {
        ["&quot;"] = '"',
        ["&apos;"] = "'",
        ["&#39;"] = "'",
        ["&lt;"] = "<",
        ["&gt;"] = ">",
        ["&amp;"] = "&",
        ["&nbsp;"] = " ",
    }

    for entity, char in pairs(entities) do
        text = text:gsub(entity, char)
    end

    return text
end

-- Extract meta tag content by property
-- Handles multiple attribute orderings and quote styles
local function extract_meta_content(html, property)
    -- Escape special pattern characters in property name
    local escaped_prop = property:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")

    -- Match the entire meta tag with this property
    -- This handles attributes in any order
    local pattern = '<meta[^>]*' .. 'property="' .. escaped_prop .. '"[^>]*>'
    local tag = html:match(pattern)

    if not tag then
        -- Try with name attribute instead
        pattern = '<meta[^>]*' .. 'name="' .. escaped_prop .. '"[^>]*>'
        tag = html:match(pattern)
    end

    if not tag then
        return nil
    end

    -- Extract content from the matched tag
    -- Try double quotes first, then single quotes
    local content = tag:match('content="([^"]*)"')
    if not content then
        content = tag:match("content='([^']*)'")
    end

    return content
end

-- Parse Instagram post HTML and extract structured data
-- @param html string The HTML content of an Instagram post page
-- @return table Structured data containing description, image_url, title, url
function M.parse(html)
    if not html or type(html) ~= "string" then
        error("parse() requires HTML string as argument")
    end

    local description = extract_meta_content(html, "og:description")
    local image = extract_meta_content(html, "og:image")
    local title = extract_meta_content(html, "og:title")
    local url = extract_meta_content(html, "og:url")

    -- Decode HTML entities in text fields and URLs
    description = decode_html_entities(description)
    title = decode_html_entities(title)
    image = decode_html_entities(image)
    url = decode_html_entities(url)

    return {
        description = description,
        image_url = image,
        title = title,
        url = url
    }
end

return M
