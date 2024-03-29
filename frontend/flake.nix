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
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs.elmPackages; [
            elm
            elm-format
            elm-json
            elm-test
            elm-review
            elm-language-server

            pkgs.nodejs
            pkgs.nodePackages.parcel
            dev
            build
            pkgs.node2nix
          ];
        };

        apps.default = {
          type = "app";
          program = "${dev}/bin/dev";
        };

      });
}
