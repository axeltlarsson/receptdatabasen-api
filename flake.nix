{
  description = "Receptdatabasen";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        pg = pkgs.postgresql_12;
        db = pkgs.writeShellApplication {
          # TODO: would be pretty sick with command line completion 🤓
          name = "db";
          runtimeInputs = [ pg ];
          text = pkgs.lib.strings.fileContents ./scripts/db.sh;
        };
      in {

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [ pkgs.bashInteractive ];
          buildInputs = [ db pkgs.shellcheck ];

          # source the .env file
          shellHook = ''
            set -a
            source .env
            set +a
          '';

        };
      });
}
