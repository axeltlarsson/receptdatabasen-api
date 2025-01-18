{ pkgs, ... }:
pkgs.mkShell {
  packages = with pkgs.elmPackages; [
    elm
    elm-format
    elm-json
    elm-test
    elm-review
    elm-language-server

    pkgs.nodejs
    pkgs.nodePackages.parcel
    # dev
    # build
    pkgs.node2nix
  ];
}
