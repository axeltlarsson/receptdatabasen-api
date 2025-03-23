{
  system,
  ...
}:
let
  # current nixpkgs demandes to build ghc with big-parallell for elm-format...
  # which is *not* something I want to do, so I just pin it here for now
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/refs/tags/24.11.tar.gz";
    sha256 = "sha256:1gx0hihb7kcddv5h0k7dysp2xhf1ny0aalxhjbpj2lmvj7h9g80a";
  }) { inherit system; };
in
pkgs.mkShell {
  packages = with pkgs.elmPackages; [
    elm
    elm-format
    elm-json
    elm-test
    elm-review
    elm-language-server

    pkgs.nodejs
    pkgs.nodePackages.uglify-js

  ];
}
