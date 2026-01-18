#!/usr/bin/env luajit
-- Test script for recipe_extractor
-- Run: luajit test_extractor.lua [filename]

local parser = require("instagram_parser")
local extractor = require("recipe_extractor")
local cjson = require("cjson")

-- Test data directory
local TEST_DATA_DIR = "test_data/"

-- Helper to read file
local function read_file(filename)
    local file = io.open(filename, "r")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    return content
end

-- Helper to print section
local function print_section(name, value)
    print(string.format("\n=== %s ===", name))
    if value == nil then
        print("(nil)")
    elseif type(value) == "table" then
        print(cjson.encode(value))
    elseif type(value) == "string" then
        -- Truncate long strings
        if #value > 500 then
            print(value:sub(1, 500) .. "\n... [truncated]")
        else
            print(value)
        end
    else
        print(tostring(value))
    end
end

-- Test a single file
local function test_file(filename)
    print(string.rep("=", 60))
    print("FILE: " .. filename)
    print(string.rep("=", 60))

    -- Try with test_data prefix first, then without (for direct paths)
    local filepath = TEST_DATA_DIR .. filename
    local html = read_file(filepath)
    if not html then
        html = read_file(filename)  -- Try direct path
        filepath = filename
    end
    if not html then
        print("ERROR: Could not read file")
        return
    end

    -- Parse HTML to get og:description
    local parsed = parser.parse(html)
    if not parsed.description then
        print("WARNING: No og:description found in HTML")
        return
    end

    -- Extract recipe
    local result = extractor.extract(parsed.description)

    -- Print results
    print_section("IS RECIPE", result.is_recipe)
    print_section("TITLE", result.title)
    print_section("PORTIONS", result.portions)
    print_section("DESCRIPTION", result.description)
    print_section("INGREDIENTS", result.ingredients)
    print_section("INSTRUCTIONS", result.instructions)
    print_section("TAGS", result.tags)
end

-- Main
local args = {...}
if #args > 0 then
    -- Test specific file(s)
    for _, filename in ipairs(args) do
        test_file(filename)
        print("\n")
    end
else
    -- Test a few sample files
    local test_files = {
        "majssallad.txt",           -- Swedish, DU BEHÖVER + GÖR SÅHÄR
        "test_curl.txt",            -- Swedish, UPPERCASE sections
        "pad_kra_pao.html",         -- English, Ingredients:
        "punjabi_style_chicken_masala.html",  -- English, Recipe Ingredients + Serves
        "best_lemonade_in_the_world.html",    -- English, Ingredients + Directions
        "crispy_chilli_beef.html",  -- Swedish, numbered steps
        "espresso_martini.html",    -- Simple list
        "how_to_cook_a_steak_in_a_cast_iron_pan_not_a_recipe.html",  -- Not a recipe
    }

    for _, filename in ipairs(test_files) do
        local exists = io.open(TEST_DATA_DIR .. filename, "r")
        if exists then
            exists:close()
            test_file(filename)
            print("\n")
        end
    end
end
