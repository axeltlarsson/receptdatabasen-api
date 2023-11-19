# receptdatabasen-api

_The new PostgREST backend and Elm frontend for receptdatabasen_

## Setup

Once do:
`(cd frontend && docker build -t receptdatabasen_frontend_builder .)`
so that the openresty service can be spun up happily.

then run:

```bash
docker compose up
```

And then see [frontend](./frontend/) for spinning up the Elm frontend.

### Running with nginx prod conf in development

Build a prod version of the frontend with `npm run build` in the `frontend` directory, then simply visit `localhost:8080` instead of `localhost:3000` as for the elm-app _dev_ server.

## API


### Authentication with Username/Password

```sh
curl -c cookie.txt -H 'content-type: application/json' -d '{"user_name": "xxx", "password": "yyy"}' localhost:1234/rest/login
curl -b cookie.txt -H 'content-type: application/json' localhost:1234/rest/rpc/me
```

### Authentication with Passkeys

Passkey support on the BE side is implemented with the help of the Python [webauthn lib](https://github.com/duo-labs/py_webauthn/tree/master).

1. The client with a valid session calls `GET /rest/passkeys/registration/begin` to get the "registration options" including a random challenge.
    - options are generated with `webauthn.generate_registration_options()`
1. The client creates a passkey with `navigator.credentials.create` using the options from step 1.
1. The client calls `POST /rest/passkeys/registration/complete` with the serialised passkey (the public key).
    - the server verifies that the public key is valid and contains the right challenge with `webauth.verify_registration_response()`
    - the server stores the public key in the passkeys table



Using [httpie](https://httpie.org/doc) it's very easy to interact with the API:

- `http POST :8080/rest/recipes < data/cheese_cake.json` - to create a recipe
- `http :8080/rest/recipes` - get the list of recipes
- `http :8080/rest/recipes title="eq.Cheese Cake"` - get a recipe by title
- `http PATCH :8080/rest/recipes title="eq.Cheese Cake" portions:=23 tags:='["efterätt", "dessert"]'` - edit the recipe
- `http :8080/rest/rpc/search search_query='fläsk'` - full text search with prefix matching

## Testing

The starter kit comes with a testing infrastructure setup.
You can write pgTAP tests that run directly in your database, useful for testing the logic that resides in your database (user privileges, Row Level Security, stored procedures).
Integration tests are written in JavaScript (in process of migration to Python - e.g. for passkeys).

Here is how you run them

```bash
npm install                     # Install test dependencies
npm test                        # Run all tests (db, rest)
npm run test_db                 # Run pgTAP tests
npm run test_rest               # Run integration tests
npm run test_image_server
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

## Importing production database

`import_prod_db.sh` or with Nix devShell `import-prod`.

N.B! `JWT_SECRET` and `COOKIE_SECRET` need to match from prod unless you create a new user manually (future improvement for the script).
N.B! The image download doesn't work.

## Deployment

Add the production host as a bare git repo, and set up the post-recieve hook, then see scripts/deploy.

## Migrations 🗃

```sh
sqitch --chdir db/migrations add <name_of_migration> --note "<note of migration>"
```

Run the `hot-reload` script for hot reloading openresty and db.
Whenever any source files changes in db/ the last migration is first rolled back, then re-applied.

## Authentication and Authorization flow

PostgREST uses jwt to authenticate users, and Postgres roles and RLS and to authorize.
See https://postgrest.org/en/v7.0.0/auth.html for more details.

However, they are quite clear in their communication that jwt:s are **not suitable for sessions**.
As numerous others have pointed out over the years, e.g. http://cryto.net/~joepie91/blog/2016/06/13/stop-using-jwt-for-sessions/.
There are some great articles about using jwt:s on the frontend, like https://hasura.io/blog/best-practices-of-using-jwt-with-graphql/.
However, that guide does stil admit that its solution is not perfect, even if you do go through all that trouble, with refresh tokens and whatnot (there is by default a refresh_token function in this repo actually).

I then came across this project, but with this issue https://github.com/monacoremo/postgrest-sessions-example/issues/21.
And decided to store the jwt in a plain old cookie, using this excellent library: https://github.com/bungle/lua-resty-session.
Some inspiration for the actual lua code in openresty I found here https://ehsanfa.hashnode.dev/use-nginx-as-jwt-authentication-middleware-cjz4cwjmt002egls183sa5lvq.

In general it seems like it is far from trivial to implement this correctly, even after doing quite a bit of research, and reading about OAuth 2.0, on Okta and Auth0, it seems that spec is very difficult to make 100 % safe for web apps actually, owing to some recent browser changes in how they treat cookies from third parties.

All in all, that is why I chose to go with this quite simple solution of storing the jwt token in a secure cookie.

---

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
