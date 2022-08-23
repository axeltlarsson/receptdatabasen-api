{
  description = "receptdatabasen frontend";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        dev = pkgs.writeScriptBin "dev" ''
          npm start
        '';

        build = pkgs.writeScriptBin "build" ''
          npm run build
        '';

      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs.elmPackages; [
            elm
            elm-format
            elm-json
            elm-test
            elm-review
            elm-language-server

            pkgs.nodejs
            dev
            build
          ];
        };
      });
}
