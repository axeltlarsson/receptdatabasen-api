# Receptdatabasen SPA

## Setup

- Active the nix shell (`nix develop` / `direnv allow`).
- `npm install` (on first setup only)

## Develop

Run it in dev mode with: `dev` or `nix run`.

## Build

- `build`

Use elm-review to find and remove dead code: `npx elm-review --fix`.

Use `elm-test` to run the unit tests.

[Parcel](https://parceljs.org/) is used to bundle the app for prod and to provide a nice dev server.
