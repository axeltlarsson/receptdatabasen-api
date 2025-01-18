{
  system,
  ...
}:
let
  # pinned nixpkgs at workable commit, for now
  pkgs = import (builtins.fetchTarball {
    url = "github:nixos/nixpkgs#2b9c57d33e3d5be6262e124fc66e3a8bc650b93d";
    sha256 = "sha256-1F7hDLj58OQCADRtG2DRKpmJ8QVza0M0NK/kfLWLs3k=";
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
    pkgs.nodePackages.parcel
    # dev
    # build
    pkgs.node2nix
  ];
}
