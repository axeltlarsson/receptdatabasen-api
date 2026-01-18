-- Recipe Extractor Module
-- Extracts structured recipe data from Instagram post descriptions
-- using rules-based pattern matching

local M = {}

-- Normalize curly quotes to straight quotes for easier matching
local function normalize_quotes(text)
    if not text then return text end
    -- Replace curly single quotes with straight
    text = text:gsub("\xe2\x80\x99", "'")  -- ' (right single quote)
    text = text:gsub("\xe2\x80\x98", "'")  -- ' (left single quote)
    -- Replace curly double quotes with straight
    text = text:gsub("\xe2\x80\x9c", '"')  -- " (left double quote)
    text = text:gsub("\xe2\x80\x9d", '"')  -- " (right double quote)
    return text
end

-- Portion patterns (captures the number)
local portion_patterns = {
    "(%d+)%s*personer",                     -- "2 personer"
    "%((%d+)%s*pers%)",                     -- "(6 pers)"
    "[Ss]erves%s*(%d+)",                    -- "Serves 4"
    "[Ss]erves%s*%d+%-(%d+)",               -- "Serves 3-4" (take upper bound)
    "[Ff]or%s+about%s+(%d+)%s+servings",    -- "for about 4 servings"
    "[Tt]his%s+make[s]?%s+(%d+)%s+portions", -- "This make 4 portions"
    "[Rr]äcker%s+till%s+(%d+)",             -- "Räcker till 4"
    "[Rr]eceptet%s+räcker%s+till%s+(%d+)",  -- "Receptet räcker till 1"
}

-- Ingredients section markers (plain text, will be escaped in find_marker)
-- Note: curly quotes are normalized to straight quotes before matching
local ingredients_markers = {
    "Ingredients:",
    "Ingredients;",
    "Ingredients (",  -- "Ingredients (for about 4 servings):"
    "Recipe Ingredients",
    "Basic Ingredients:",
    "DU BEHÖVER",
    "Ingredienser:",
    "RECEPT:",        -- Swedish "recipe" followed by ingredients
    "Här är receptet:",  -- Swedish "Here is the recipe:"
    "Let's make it at home:",  -- Casual English intro to recipe
    "Let's make it:",
    "make it at home:",  -- Simpler variant
    "Focaccia :",     -- Some recipes use dish name as section header
    "Flatbread:",
}

-- UPPERCASE section headers that typically contain ingredients
local uppercase_ingredient_headers = {
    "BULJONG",
    "FÄRS",
    "TARE",
    "SALLAD",
    "DRESSING",
    "MARINAD",
    "SÅS",
    "TOPPING",
}

-- Sub-section headers (Swedish style with colon)
local subsection_ingredient_headers = {
    "Dressing:",
    "Sallad:",
    "Woksås:",
    "Marinad:",
    "Topping:",
    "Pankokrisp:",
    "Sås:",
    "Kyckling:",
    "Risoni:",
    "Flatbread:",
    "Stuffing:",
    "Sesampotatis:",
    "Garlic Chilli Oil",
    "Chilli Oil Noodles",
}

-- Instructions section markers
local instructions_markers = {
    "Directions:",
    "Method:",
    "Steps:",
    "Instructions:",
    "GÖR SÅHÄR:",
    "Gör såhär:",
    "GÖR SÅ HÄR:",
    "Gör så här:",
}

-- Action verb markers that indicate paragraph instructions
-- These are only used when they appear at start of line after ingredients
local action_verb_markers = {
    "Grädda ",      -- Swedish: "Bake"
    "Stek ",        -- Swedish: "Fry"
    "Koka ",        -- Swedish: "Boil/Cook"
    "Blanda ",      -- Swedish: "Mix"
    "Värm ",        -- Swedish: "Heat"
    "Vispa ",       -- Swedish: "Whip/Whisk"
}

-- Sub-section markers (often used in Swedish recipes for ingredient groups)
local subsection_patterns = {
    "^[A-ZÅÄÖ][A-ZÅÄÖ]+:?$",  -- UPPERCASE headers like "BULJONG", "FÄRS"
    "^[A-ZÅÄÖ][A-ZÅÄÖ ]+:$",  -- UPPERCASE with spaces like "GARLIC CHILLI OIL:"
}

-- Extract hashtags from text
local function extract_hashtags(text)
    if not text then return {} end
    local tags = {}
    for tag in text:gmatch("#([%w_]+)") do
        table.insert(tags, tag:lower())
    end
    return tags
end

-- Remove hashtags section from text (usually at the end)
local function remove_hashtags(text)
    if not text then return "" end
    -- Find where hashtags start (first # followed by word chars)
    local hashtag_start = text:find("\n#[%w_]")
    if hashtag_start then
        return text:sub(1, hashtag_start - 1):gsub("%s+$", "")
    end
    -- Also try without newline (hashtags at very end)
    hashtag_start = text:find("%s#[%w_]")
    if hashtag_start then
        return text:sub(1, hashtag_start - 1):gsub("%s+$", "")
    end
    return text
end

-- Extract portions from text
local function extract_portions(text)
    if not text then return nil end
    for _, pattern in ipairs(portion_patterns) do
        local num = text:match(pattern)
        if num then
            return tonumber(num)
        end
    end
    return nil
end

-- Find position of first matching marker (case-insensitive)
local function find_marker(text, markers)
    if not text then return nil, nil end
    local best_pos = nil
    local best_marker = nil

    for _, marker in ipairs(markers) do
        -- Escape special pattern characters
        local escaped = marker:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
        -- Case-insensitive search
        local lower_text = text:lower()
        local lower_marker = escaped:lower()
        local pos = lower_text:find(lower_marker)
        if pos and (not best_pos or pos < best_pos) then
            best_pos = pos
            best_marker = marker
        end
    end

    return best_pos, best_marker
end

-- Find first numbered step (1. or 1))
local function find_first_numbered_step(text)
    if not text then return nil end
    -- Look for "1." or "1)" at start of line
    local pos = text:find("\n1[%.%)]%s")
    if pos then return pos + 1 end  -- +1 to skip the newline
    -- Also check at very start
    if text:match("^1[%.%)]%s") then return 1 end
    return nil
end

-- Find first bullet point (• or - at start of line for instructions)
local function find_first_bullet(text)
    if not text then return nil end
    local pos = text:find("\n[•%-]%s")
    if pos then return pos + 1 end
    if text:match("^[•%-]%s") then return 1 end
    return nil
end

-- Check if a line looks like an UPPERCASE section header
local function is_uppercase_header(line)
    if not line then return false end
    local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
    if #trimmed < 3 or #trimmed > 30 then return false end
    -- Check if mostly uppercase letters (allowing some punctuation)
    local letters = trimmed:gsub("[^%a]", "")
    if #letters < 2 then return false end
    local upper = trimmed:gsub("[^A-ZÅÄÖ]", "")
    return #upper >= #letters * 0.8
end

-- Find first UPPERCASE ingredient section header
local function find_uppercase_ingredient_section(text)
    if not text then return nil end
    for _, header in ipairs(uppercase_ingredient_headers) do
        local pattern = "\n" .. header .. "\n"
        local pos = text:find(pattern)
        if pos then return pos + 1 end  -- +1 to skip the leading newline
    end
    -- Also try at start of text (after metadata)
    for _, header in ipairs(uppercase_ingredient_headers) do
        if text:find("^" .. header .. "\n") or text:find("\n\n" .. header .. "\n") then
            local pos = text:find(header .. "\n")
            if pos then return pos end
        end
    end
    return nil
end

-- Find first subsection header (e.g., "Dressing:", "Sallad:")
local function find_subsection_ingredient_header(text)
    if not text then return nil end
    local best_pos = nil
    for _, header in ipairs(subsection_ingredient_headers) do
        -- Look for header at start of line
        local pattern = "\n" .. header
        local pos = text:find(pattern, 1, true)  -- plain text search
        if pos then
            pos = pos + 1  -- skip the newline
            if not best_pos or pos < best_pos then
                best_pos = pos
            end
        end
    end
    return best_pos
end

-- Find ingredient-like list (dash-prefixed items with quantities)
-- Used as last resort when no section markers found
local function find_ingredient_like_list(text)
    if not text then return nil end
    -- Look for lines starting with "- " followed by quantity or ingredient
    -- Pattern: newline, dash, space, then number or letter
    local pos = text:find("\n%- [%d%a]")
    if pos then
        -- Verify it looks like ingredients (has quantity patterns nearby)
        local sample = text:sub(pos, pos + 200)
        if sample:match("%d+") then  -- has numbers
            return pos + 1
        end
    end
    return nil
end

-- Find action verb instructions after a given position (typically after ingredients)
-- Only matches if the verb appears at the start of a line
local function find_action_verb_instructions(text, after_pos)
    if not text or not after_pos then return nil end

    local search_text = text:sub(after_pos)
    local best_pos = nil

    for _, verb in ipairs(action_verb_markers) do
        -- Look for verb at start of line (after newline)
        local pattern = "\n" .. verb
        local pos = search_text:find(pattern, 1, true)  -- plain text search
        if pos then
            local absolute_pos = after_pos + pos  -- position in original text
            if not best_pos or absolute_pos < best_pos then
                best_pos = absolute_pos
            end
        end
    end

    return best_pos
end

-- Find start of quantity-based ingredient list (e.g., "250 gr spaghetti", "1 cup flour")
-- This detects lists that start with a number+unit pattern on their own line
local function find_quantity_list_start(text, before_pos)
    if not text then return nil end
    before_pos = before_pos or #text

    -- Common quantity patterns at start of line:
    -- "250 gr ", "1 cup ", "2 msk ", "1/2 oz ", ".5 oz ", "½ tsp "
    local quantity_patterns = {
        "\n(%d+)%s*gr%s",           -- "250 gr"
        "\n(%d+)%s*g%s",            -- "250 g"
        "\n(%d+)%s*ml%s",           -- "100 ml"
        "\n(%d+)%s*dl%s",           -- "2 dl"
        "\n(%d+)%s*msk%s",          -- "2 msk"
        "\n(%d+)%s*tsk%s",          -- "1 tsk"
        "\n(%d+)%s*tbsp%s",         -- "2 tbsp"
        "\n(%d+)%s*tsp%s",          -- "1 tsp"
        "\n(%d+)%s*cup",            -- "2 cups"
        "\n(%d+)%s*oz%s",           -- "2 oz"
        "\n(%d+/%d+)%s*oz%s",       -- "1/2 oz"
        "\n(%d+/%d+)%s*cup",        -- "1/2 cup"
        "\n%.%d+%s*oz%s",           -- ".5 oz"
        "\n(%d+)%s*skivor?%s",      -- "4 skivor" (Swedish: slices)
        "\n(%d+)%s*st%s",           -- "2 st" (Swedish: pieces)
        "\n(%d+)%s*klyftor?",       -- "3 klyftor" (Swedish: cloves)
        "\n(%d+)%s*mogna?%s",       -- "2 mogna" (Swedish: ripe)
    }

    local best_pos = nil
    for _, pattern in ipairs(quantity_patterns) do
        local pos = text:find(pattern)
        if pos and pos < before_pos then
            if not best_pos or pos < best_pos then
                best_pos = pos + 1  -- +1 to skip the newline
            end
        end
    end

    -- Verify we found a list (at least 3 quantity lines in a row)
    if best_pos then
        local sample = text:sub(best_pos, math.min(best_pos + 500, before_pos))
        local quantity_lines = 0
        for line in sample:gmatch("[^\n]+") do
            if line:match("^%d") or line:match("^%.%d") or line:match("^%d+/%d+") then
                quantity_lines = quantity_lines + 1
            end
        end
        if quantity_lines >= 2 then
            return best_pos
        end
    end

    return nil
end

-- Extract title from text
-- Strategy: First sentence, or UPPERCASE header at start
local function extract_title(text)
    if not text then return nil end

    -- Remove the "X likes, Y comments - username on Date:" prefix from og:description
    local cleaned = text:gsub("^%d[%d,K]*%s+likes?,%s+%d+%s+comments?%s+%-%s+[%w_]+%s+on%s+[%w%s,]+:%s*", "")
    cleaned = cleaned:gsub("^\"", ""):gsub("\"%s*$", "")  -- Remove surrounding quotes

    -- Check for UPPERCASE title at very start
    local first_line = cleaned:match("^([^\n]+)")
    if first_line and is_uppercase_header(first_line) then
        return first_line:gsub("^%s+", ""):gsub("%s+$", "")
    end

    -- Take first sentence (up to . ! or ?)
    local first_sentence = cleaned:match("^([^%.!?]+[%.!?]?)")
    if first_sentence then
        first_sentence = first_sentence:gsub("^%s+", ""):gsub("%s+$", "")
        -- Truncate if too long
        if #first_sentence > 100 then
            first_sentence = first_sentence:sub(1, 97) .. "..."
        end
        return first_sentence
    end

    return nil
end

-- Extract intro/description (text before first section marker)
local function extract_intro(text, ingredients_pos, instructions_pos)
    if not text then return nil end

    -- Remove the "X likes, Y comments..." prefix
    local cleaned = text:gsub("^%d[%d,K]*%s+likes?,%s+%d+%s+comments?%s+%-%s+[%w_]+%s+on%s+[%w%s,]+:%s*", "")
    cleaned = cleaned:gsub("^\"", "")

    -- Find the earliest section marker
    local end_pos = #cleaned
    if ingredients_pos then end_pos = math.min(end_pos, ingredients_pos - 1) end
    if instructions_pos then end_pos = math.min(end_pos, instructions_pos - 1) end

    -- Also stop at portion markers
    for _, pattern in ipairs(portion_patterns) do
        local pos = cleaned:find(pattern)
        if pos then end_pos = math.min(end_pos, pos - 1) end
    end

    local intro = cleaned:sub(1, end_pos)
    intro = intro:gsub("%s+$", "")  -- trim trailing whitespace

    -- Don't return if too short
    if #intro < 20 then return nil end

    -- Truncate if too long (for description field)
    if #intro > 700 then
        intro = intro:sub(1, 697) .. "..."
    end

    return intro
end

-- Extract ingredients section
local function extract_ingredients(text, start_pos, end_pos)
    if not text or not start_pos then return nil end

    end_pos = end_pos or #text
    local section = text:sub(start_pos, end_pos)

    -- Check if first line looks like an ingredient (starts with number/quantity)
    -- If so, don't skip it. Otherwise, skip the marker line.
    local first_line = section:match("^([^\n]*)")
    local first_is_ingredient = first_line and (
        first_line:match("^%d") or           -- Starts with number
        first_line:match("^%.%d") or         -- Starts with .5
        first_line:match("^½") or            -- Starts with fraction
        first_line:match("^¼") or
        first_line:match("^¾") or
        first_line:match("^%-%s*%d") or      -- Starts with "- 2 cups"
        first_line:match("^%-%s*[½¼¾]")      -- Starts with "- ½ cup"
    )

    if not first_is_ingredient then
        -- Skip the marker line itself
        local content_start = section:find("\n")
        if content_start then
            section = section:sub(content_start + 1)
        end
    end

    -- Clean up
    section = section:gsub("^%s+", ""):gsub("%s+$", "")
    section = remove_hashtags(section)

    -- Don't return if too short
    if #section < 10 then return nil end

    return section
end

-- Extract instructions section
local function extract_instructions(text, start_pos, end_pos)
    if not text or not start_pos then return nil end

    end_pos = end_pos or #text
    local section = text:sub(start_pos, end_pos)

    -- If starting with a marker, skip it
    for _, marker in ipairs(instructions_markers) do
        if section:lower():find("^" .. marker:lower():gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")) then
            local content_start = section:find("\n")
            if content_start then
                section = section:sub(content_start + 1)
            end
            break
        end
    end

    -- Clean up
    section = section:gsub("^%s+", ""):gsub("%s+$", "")
    section = remove_hashtags(section)

    -- Don't return if too short
    if #section < 10 then return nil end

    return section
end

-- Detect if text appears to be a recipe
local function detect_is_recipe(text, has_ingredients, has_instructions)
    if not text then return false end

    -- Non-recipe indicators (recipe is elsewhere, not in this post)
    -- Only trigger if "link in bio" is specifically about the recipe
    local lower = text:lower()
    if lower:find("recipe in bio") then return false end
    if lower:find("full recipe") and lower:find("bio") then return false end
    if lower:find("recipe's available") and lower:find("bio") then return false end
    if lower:find("recipe") and lower:find("tap the link") then return false end
    if lower:find("pinned comment") then return false end  -- instructions in comment
    -- "link in bio" alone is NOT a filter - too many false positives (e.g., travel guides)

    -- Too short
    if #text < 200 then return false end

    -- Has both ingredients and instructions = definitely a recipe
    if has_ingredients and has_instructions then return true end

    -- Has ingredient-like patterns (quantities)
    local has_quantities = text:match("%d+%s*[gG]%s") or
                          text:match("%d+%s*[mM][lL]%s") or
                          text:match("%d+%s*[dD][lL]%s") or
                          text:match("%d+%s*[tT]bsp") or
                          text:match("%d+%s*[tT]sp") or
                          text:match("%d+%s*msk") or
                          text:match("%d+%s*tsk") or
                          text:match("%d+%s*cup") or
                          text:match("%d+%s*oz")

    -- Has numbered steps
    local has_steps = text:find("\n1[%.%)]%s") or text:find("\n2[%.%)]%s")

    -- Has explicit recipe markers
    local has_recipe_marker = text:lower():find("recipe ingredients") or
                              text:lower():find("ingredients:") or
                              text:lower():find("ingredienser:") or
                              text:lower():find("du behöver") or
                              text:lower():find("här är receptet")

    -- If we found ingredients, and either has quantities or recipe markers, it's likely a recipe
    if has_ingredients then
        if has_quantities or has_recipe_marker then
            return true
        end
    end

    return has_quantities and (has_instructions or has_steps)
end

-- Main extraction function
function M.extract(description)
    if not description or type(description) ~= "string" then
        return {
            title = nil,
            description = nil,
            portions = nil,
            ingredients = nil,
            instructions = nil,
            tags = {},
            is_recipe = false,
            raw_description = description or "",
        }
    end

    -- Normalize curly quotes to straight quotes for easier matching
    local normalized = normalize_quotes(description)

    -- Extract tags first (and get text without hashtags for other processing)
    local tags = extract_hashtags(normalized)
    local text_no_tags = remove_hashtags(normalized)

    -- Find section markers
    local ingredients_pos, ingredients_marker = find_marker(text_no_tags, ingredients_markers)
    local instructions_pos, instructions_marker = find_marker(text_no_tags, instructions_markers)

    -- If no standard ingredients marker, look for UPPERCASE section headers
    if not ingredients_pos then
        ingredients_pos = find_uppercase_ingredient_section(text_no_tags)
    end

    -- If still no ingredients marker, look for subsection headers (Dressing:, Sallad:, etc.)
    if not ingredients_pos then
        ingredients_pos = find_subsection_ingredient_header(text_no_tags)
    end

    -- Last resort: look for dash-prefixed ingredient lists
    if not ingredients_pos then
        ingredients_pos = find_ingredient_like_list(text_no_tags)
    end

    -- If no explicit instructions marker, look for numbered steps
    if not instructions_pos then
        instructions_pos = find_first_numbered_step(text_no_tags)
    end

    -- Another fallback: look for quantity-based ingredient lists before instructions
    if not ingredients_pos and instructions_pos then
        ingredients_pos = find_quantity_list_start(text_no_tags, instructions_pos)
    end

    -- If still no instructions, look for dash-prefixed steps after "Directions" variant
    if not instructions_pos then
        -- Check for "-" bullet instructions (common in some recipes)
        local dash_pos = text_no_tags:find("\n%-[%a%d]")
        if dash_pos then
            -- Only use if it looks like instructions (after ingredients or mid-text)
            if ingredients_pos and dash_pos > ingredients_pos then
                instructions_pos = dash_pos + 1
            end
        end
    end

    -- Fallback: look for action verb instructions after ingredients
    if not instructions_pos and ingredients_pos then
        instructions_pos = find_action_verb_instructions(text_no_tags, ingredients_pos)
    end

    -- Determine section boundaries
    local ingredients_end = nil
    if ingredients_pos then
        if instructions_pos and instructions_pos > ingredients_pos then
            ingredients_end = instructions_pos - 1
        end
    end

    -- Extract each component
    local portions = extract_portions(text_no_tags)
    local ingredients = extract_ingredients(text_no_tags, ingredients_pos, ingredients_end)
    local instructions = extract_instructions(text_no_tags, instructions_pos, nil)
    local title = extract_title(normalized)
    local intro = extract_intro(text_no_tags, ingredients_pos, instructions_pos)

    -- Detect if this is actually a recipe
    local is_recipe = detect_is_recipe(text_no_tags, ingredients ~= nil, instructions ~= nil)

    return {
        title = title,
        description = intro,
        portions = portions,
        ingredients = ingredients,
        instructions = instructions,
        tags = tags,
        is_recipe = is_recipe,
        raw_description = description,
    }
end

return M
