-- CLI wrapper for Instagram parser
-- Usage: cat post.html | luajit cli.lua
--    or: luajit cli.lua post.html

local parser = require("instagram_parser")
local cjson = require("cjson")

-- Read input (from file or stdin)
local function read_input()
    local input

    if arg[1] then
        -- Read from file
        local file = io.open(arg[1], "r")
        if not file then
            io.stderr:write("Error: Could not open file " .. arg[1] .. "\n")
            os.exit(1)
        end
        input = file:read("*all")
        file:close()
    else
        -- Read from stdin
        input = io.read("*all")
    end

    return input
end

-- Main
local html = read_input()

local ok, result = pcall(parser.parse, html)
if not ok then
    io.stderr:write("Error parsing HTML: " .. tostring(result) .. "\n")
    os.exit(1)
end

-- Output JSON
print(cjson.encode(result))
