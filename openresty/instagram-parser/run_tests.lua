#!/usr/bin/env luajit
-- Test runner for recipe_extractor
-- Compares extraction results against expected fixtures
-- Run: luajit run_tests.lua

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

-- Load test fixtures
local function load_fixtures()
    local json_content = read_file("test_fixtures.json")
    if not json_content then
        print("ERROR: Could not read test_fixtures.json")
        os.exit(1)
    end
    return cjson.decode(json_content)
end

-- Color helpers (ANSI codes)
local function green(s) return "\27[32m" .. s .. "\27[0m" end
local function red(s) return "\27[31m" .. s .. "\27[0m" end
local function yellow(s) return "\27[33m" .. s .. "\27[0m" end
local function bold(s) return "\27[1m" .. s .. "\27[0m" end

-- Test a single file
local function test_file(filename, expected)
    local html = read_file(TEST_DATA_DIR .. filename)
    if not html then
        return nil, "File not found"
    end

    local parsed = parser.parse(html)
    if not parsed.description then
        return nil, "No og:description"
    end

    -- Check if this is an "uncertain" test case (edge case)
    if expected.is_recipe == "uncertain" then
        return nil, "Edge case (uncertain)"
    end

    local result = extractor.extract(parsed.description)

    local failures = {}

    -- Check is_recipe
    if expected.is_recipe ~= nil then
        local actual_is_recipe = result.is_recipe
        -- Handle uncertain cases (nil is acceptable if expected is false or uncertain)
        if expected.is_recipe == true then
            if actual_is_recipe ~= true then
                table.insert(failures, string.format("is_recipe: expected true, got %s", tostring(actual_is_recipe)))
            end
        elseif expected.is_recipe == false then
            if actual_is_recipe == true then
                table.insert(failures, string.format("is_recipe: expected false, got true"))
            end
        end
    end

    -- Check has_ingredients
    if expected.has_ingredients then
        if not result.ingredients then
            table.insert(failures, "has_ingredients: expected ingredients, got nil")
        end
    elseif expected.has_ingredients == false then
        if result.ingredients then
            table.insert(failures, "has_ingredients: expected nil, got ingredients")
        end
    end

    -- Check has_instructions
    if expected.has_instructions then
        if not result.instructions then
            table.insert(failures, "has_instructions: expected instructions, got nil")
        end
    elseif expected.has_instructions == false then
        if result.instructions then
            table.insert(failures, "has_instructions: expected nil, got instructions")
        end
    end

    -- Check portions (only if expected is specified and not null)
    if expected.portions and expected.portions ~= cjson.null then
        if result.portions ~= expected.portions then
            table.insert(failures, string.format("portions: expected %d, got %s",
                expected.portions, tostring(result.portions)))
        end
    end

    return {
        is_recipe = result.is_recipe,
        has_ingredients = result.ingredients ~= nil,
        has_instructions = result.instructions ~= nil,
        portions = result.portions,
        failures = failures,
    }
end

-- Main
local function main()
    local fixtures = load_fixtures()
    local total = 0
    local passed = 0
    local failed = 0
    local skipped = 0
    local failed_tests = {}

    print(bold("=== Recipe Extractor Test Suite ==="))
    print("")

    -- Get sorted list of test files
    local test_files = {}
    for filename, _ in pairs(fixtures) do
        if not filename:match("^_") then  -- Skip metadata keys
            table.insert(test_files, filename)
        end
    end
    table.sort(test_files)

    -- Run tests
    for _, filename in ipairs(test_files) do
        local expected = fixtures[filename]
        if type(expected) == "table" then
            total = total + 1
            local result, error = test_file(filename, expected)

            if not result then
                skipped = skipped + 1
                print(yellow("SKIP") .. "  " .. filename .. " (" .. error .. ")")
            elseif #result.failures == 0 then
                passed = passed + 1
                print(green("PASS") .. "  " .. filename)
            else
                failed = failed + 1
                print(red("FAIL") .. "  " .. filename)
                for _, failure in ipairs(result.failures) do
                    print("       " .. failure)
                end
                table.insert(failed_tests, filename)
            end
        end
    end

    -- Summary
    print("")
    print(bold("=== Summary ==="))
    print(string.format("Total:   %d", total))
    print(string.format("Passed:  %s", green(tostring(passed))))
    print(string.format("Failed:  %s", failed > 0 and red(tostring(failed)) or tostring(failed)))
    print(string.format("Skipped: %s", skipped > 0 and yellow(tostring(skipped)) or tostring(skipped)))
    print("")

    if #failed_tests > 0 then
        print(bold("Failed tests:"))
        for _, filename in ipairs(failed_tests) do
            print("  - " .. filename)
        end
        print("")
    end

    -- Calculate accuracy
    local accuracy = total > 0 and math.floor((passed / (total - skipped)) * 100) or 0
    print(string.format("Accuracy: %d%%", accuracy))

    return failed == 0 and 0 or 1
end

os.exit(main())
