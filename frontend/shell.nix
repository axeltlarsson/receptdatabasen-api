{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs.elmPackages; [
    # elmPackages
    elm
    elm-format
    elm-json
    elm-test
    create-elm-app

  ];
}
