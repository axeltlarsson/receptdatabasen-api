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

        nodeDependencies =
          (pkgs.callPackage ./default.nix { inherit pkgs; }).nodeDependencies;

      in {
        packages.default = pkgs.stdenv.mkDerivation {
          name = "my-parcel-app";
          src = ./.;
          buildInputs = [ pkgs.nodejs pkgs.nodePackages.parcel ];
          buildPhase = ''
            ln -s ${nodeDependencies}/lib/node_modules ./node_modules
            export PATH="${nodeDependencies}/bin:$PATH"
            export HOME=$(mktemp -d) # solves non-writable /homeless-shelter issue
            # Build the distribution bundle in "dist"
            echo parcel command coming up
            rm -rf dist
            parcel --version
            parcel build src/index.html
            # npm run build
            cp -R dist/* $out/
          '';
          installPhase = "";
        };
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
      });
}
