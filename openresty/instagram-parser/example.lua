-- Example: Using instagram_parser as a module

local parser = require("instagram_parser")

-- Example: Parse HTML from a string
local html = [[
<html>
<head>
<meta property="og:title" content="Test Post" />
<meta property="og:description" content="Swedish chars: &#xe4; &#xf6; &#xe5;" />
<meta property="og:image" content="https://example.com/image.jpg?foo=bar&amp;baz=qux" />
<meta property="og:url" content="https://instagram.com/p/test/" />
</head>
</html>
]]

local result = parser.parse(html)

print("Title:", result.title)
print("Description:", result.description)
print("Image URL:", result.image_url)
print("URL:", result.url)

-- In OpenResty, you'd use it like:
-- local parser = require("instagram_parser")
-- local http = require("resty.http")
-- local httpc = http.new()
-- local res, err = httpc:request_uri("https://instagram.com/p/...")
-- local data = parser.parse(res.body)
