local markdown_parser = require "shoppinglist/markdown_parser"
local utils = require "utils"
local jwt_helper = require "shoppinglist/jwt_helper"
local recipe_service = require "shoppinglist/recipe_service"
local shoppinglist_client = require "shoppinglist/shoppinglist_client"
local cjson = require "cjson"

-- Extract the recipe slug from the URL
local recipe_id_match = ngx.re.match(ngx.var.uri, "^/export_to_list/(\\d+)$")
local recipe_slug = recipe_id_match and recipe_id_match[1]
if not recipe_slug then
    utils.return_error("Invalid recipe ID in URL", ngx.HTTP_BAD_REQUEST)
end

-- Fetch the recipe ingredients and user information
local recipe = recipe_service.get_recipe_ingredients(recipe_slug)
local user_name = recipe_service.get_user_name()

ngx.log(ngx.INFO, "Adding ingredients for user: " .. user_name)

-- Parse the markdown ingredients into structured format
local parsed_ingredients = markdown_parser.parse(recipe.ingredients)

-- Generate a JWT token for authentication
local jwt_token = jwt_helper.generate(user_name, os.getenv("LISTAN_JWT_SECRET"))

-- Prepare the API URL and payload
local api_url = os.getenv("LISTAN_API_URL") .. "/lists/batch"

-- Send ingredients to the shopping list API and send ok response back
local ok, err = pcall(function()
    local response = shoppinglist_client.send_ingredients(api_url, jwt_token, parsed_ingredients)
    ngx.status = ngx.HTTP_OK
    ngx.say(cjson.encode(response))
end)

if not ok and err then
    ngx.log(ngx.ERR, "Error: ", err)
    utils.return_error(err, ngx.HTTP_INTERNAL_SERVER_ERROR)
end
