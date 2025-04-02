// This file bridges between the pre-compiled Elm and your JS imports
// we need this becuase @parcel/elm-transformer depends on the official
// npm package `elm` which doesn't support Linux ARM or Nix
// there is a possibility to override the `elm` package with a @lydell/elm
// however that would only give us Linux ARM support, not Nix suport
// so instead we keep parcel for now, but we don't use elm-transformer but instead
// use the raw-transformer for elm files and "manually" do `elm make`
import { Elm } from '../elm-output.js';

export { Elm };
