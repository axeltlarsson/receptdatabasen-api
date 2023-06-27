{
  description = "Receptdatabasen";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        pg = pkgs.postgresql_12;
        import_prod = pkgs.writeShellApplication {
          name = "import-prod";
          runtimeInputs = [ pkgs.docker pkgs.docker-compose ];
          text = pkgs.lib.strings.fileContents ./scripts/import_prod_db.sh;
        };
      in
      {

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [ pkgs.bashInteractive ];
          buildInputs = [
            import_prod
            pkgs.shellcheck
            pkgs.sqitchPg
            pkgs.postgresql_12
          ];

          # source the .env file
          shellHook = ''
            set -a
            source .env
            set +a
          '';

        };
      });
}
