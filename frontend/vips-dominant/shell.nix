{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs.elmPackages;
    [
      pkgs.python2

    ];
}
