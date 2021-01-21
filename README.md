# receptdatabasen-api

_The new PostgREST backend and Elm frontend for receptdatabasen_

## Development

To run:

```bash
docker-compose up
```

And then see [frontend](./frontend/) for spinning up the Elm frontend.

### Running with nginx prod conf in development

Build a prod version of the frontend with `npm run build` in the `frontend` directory, then simply visit `localhost:8080` instead of `localhost:3000` as for the elm-app _dev_ server.
The onlye difference between a real prod and this setup is that you likely don't have a reverse proxy for TLS termination in front, and that `openresty/nginx_prod` conf is not used.

Download the production database: `./import_prod_db.sh --download <host>`

### API

Using [httpie](https://httpie.org/doc) it's very easy to interact with the API:

- `http POST :8080/rest/recipes < data/cheese_cake.json` - to create a recipe
- `http :8080/rest/recipes` - get the list of recipes
- `http :8080/rest/recipes title="eq.Cheese Cake"` - get a recipe by title
- `http PATCH :8080/rest/recipes title="eq.Cheese Cake" portions:=23 tags:='["efterätt", "dessert"]'` - edit the recipe
- `http :8080/rest/rpc/search search_query='fläsk'` - full text search with prefix matching

## Testing

The starter kit comes with a testing infrastructure setup.
You can write pgTAP tests that run directly in your database, useful for testing the logic that resides in your database (user privileges, Row Level Security, stored procedures).
Integration tests are written in JavaScript.

Here is how you run them

```bash
npm install                     # Install test dependencies
npm test                        # Run all tests (db, rest)
npm run test_db                 # Run pgTAP tests
npm run test_rest               # Run integration tests
```

## Image upload endpoint

Example usage:

```bash
http -v POST :8080/images/upload Content-type:image/jpeg < test.jpeg
```

Testing:

```shell
npm run test_image_server
```

## PostgREST Starter Kit

Base project and tooling for authoring REST API backends with [PostgREST](https://postgrest.com).

![PostgREST Starter Kit](https://raw.githubusercontent.com/wiki/subzerocloud/postgrest-starter-kit/images/postgrest-starter-kit.gif "PostgREST Starter Kit")

## Purpose

PostgREST enables a different way of building data driven API backends. It does "one thing well" and that is to provide you with a REST api over your database, however to build a complex production system that does things like talk to 3rd party systems, sends emails, implements real time updates for browsers, write integration tests, implement authentication, you need additional components. For this reason, some developers either submit feature requests that are not the scope of PostgREST or think of it just as a prototyping utility and not a powerful/flexible production component with excellent performance. This repository aims to be a starting point for all PostgREST based projects and bring all components together under a well defined structure. We also provide tooling that will aid you with iterating on your project and tools/scripts to enable a build pipeline to push everything to production. There are quite a few components in the stack but you can safely comment out pg_amqp_bridge/rabbitmq (or even openresty) instances in docker-compose.yml if you don't need the features/functionality they provide.

## Directory Layout

```bash
.
├── db                        # Database schema source files and tests
│   └── src                   # Schema definition
│       ├── api               # Api entities avaiable as REST endpoints
│       ├── data              # Definition of source tables that hold the data
│       ├── libs              # A collection modules of used throughout the code
│       ├── authorization     # Application level roles and their privileges
│       ├── sample_data       # A few sample rows
│       └── init.sql          # Schema definition entry point
├── openresty                 # Reverse proxy configurations and Lua code
│   ├── lua                   # Application Lua code
│   ├── nginx                 # Nginx configuration files
│   ├── html                  # Static frontend files
│   └── Dockerfile            # Dockerfile definition for building production images
├── tests                     # Tests for all the components
│   ├── db                    # pgTap tests for the db
│   └── rest                  # REST interface tests
├── docker-compose.yml        # Defines Docker services, networks and volumes
└── .env                      # Project configurations

```

## Development workflow and debugging

Execute `subzero dashboard` in the root of your project.<br /> (Install [subzero-cli](https://github.com/subzerocloud/subzero-cli))
After this step you can view the logs of all the stack components (SQL queries will also be logged) and
if you edit a sql/conf/lua file in your project, the changes will immediately be applied.

Refresh schema by force: `docker-compose kill -s "SIGUSR1" server`
