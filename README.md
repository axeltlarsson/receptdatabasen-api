# receptdatabasen-api
*The new PostgREST backend for receptdatabasen*

## Run
`docker-compose up`

Will set up the database schema as defined in [schema.sql](./db_scripts/schema.sql).

### Communication
- `http :3000/recipes` - get the list of recipes
- `http :3000/recipes title=="eq.the recipe title"` - get a recipe by title

### API
Visit [localhost:8080](http://localhost:8080) to get a Swagger UI.
