{
  description = "receptdatabasen frontend";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        dev = pkgs.writeScriptBin "dev" ''
          elm-app start
        '';

      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs.elmPackages; [
            elm
            elm-format
            elm-json
            elm-test
            create-elm-app

            dev
          ];
        };
      });
}
