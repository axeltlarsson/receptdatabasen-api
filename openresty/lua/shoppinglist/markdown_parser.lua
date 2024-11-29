--- Module for parsing markdown ingredients.
-- This module flattens sections and their ingredients into a single list.
local M = {}

--- Trim leading and trailing whitespace.
-- @param s string The string to trim.
-- @return string The trimmed string.
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

--- Parse markdown text into a flattened list of ingredients.
-- Each section header (prefixed with one #) and its associated ingredients are included in the list.
-- @param markdown string The markdown text to parse.
-- @return table A flat list of ingredients with section headers prefixed by #.
function M.parse(markdown)
    local flat_ingredients = {}

    for line in markdown:gmatch("[^\r\n]+") do
        -- Match section headers (e.g., #, ##, ###)
        local section = line:match("^%s*#+%s*(.+)")
        if section then
            table.insert(flat_ingredients, "# " .. trim(section)) -- Add the section header with one #
        -- Match list items (e.g., - ingredient)
        elseif line:match("^%s*%-") then
            local item = line:match("^%s*%-+%s*(.+)")
            if item then
                table.insert(flat_ingredients, trim(item)) -- Add the ingredient
            end
        end
    end

    return flat_ingredients
end

return M
