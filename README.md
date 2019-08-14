# receptdatabasen-api
*The new PostgREST backend and Elm frontend for receptdatabasen*

See [frontend](./frontend/) for the Elm frontend.

## Run
`docker-compose up`

Will set up the database schema as defined in [schema.sql](./db_scripts/schema.sql).

### API
Visit [localhost:8080](http://localhost:8080) to get a Swagger UI.
Using [httpie](https://httpie.org/doc) it's very easy to interact with the API:

- `http POST :3000/recipes < example_recipe.json` - to create a recipe
- `http :3000/recipes` - get the list of recipes
- `http :3000/recipes title=="eq.Cheese Cake"` - get a recipe by title
- `http PATCH :3000/recipes title=="eq.Cheese Cake" quantity:=23 tags:='["efterätt", "dessert"]'` - edit the recipe


