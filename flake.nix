{
  description = "Receptdatabasen";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.nixpkgs_24_05.url = "github:NixOS/nixpkgs/nixpkgs-24.05-darwin";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs_24_05,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pkgs_24_05 = nixpkgs_24_05.legacyPackages.${system};

        pyPkgs = pkgs.python311Packages;

        soft-webauthn = (
          pyPkgs.buildPythonPackage rec {
            pname = "soft-webauthn";
            version = "0.1.4";
            src = pkgs.fetchPypi {
              inherit pname version;
              sha256 = "sha256-6WUTNC5pu/3lpgrcsDqw1WLXDV0uIO5yA/z7308bBtA=";
            };
            doCheck = false;
            # format = "pyproject";
            propagatedBuildInputs = with pyPkgs; [
              cryptography
              fido2
            ];

            pythonImportsCheck = [ "soft_webauthn" ];
          }
        );
        # );
        pythonEnv = pkgs.python311.withPackages (ps: [
          ps.requests
          ps.pytest
          ps.webauthn
          soft-webauthn
        ]);

        pg = pkgs_24_05.postgresql_12;
        import_prod = pkgs.writeShellApplication {
          name = "import-prod";
          runtimeInputs = [
            pkgs.docker
            pkgs.docker-compose
          ];
          text = pkgs.lib.strings.fileContents ./scripts/import_prod_db.sh;
        };

        db = pkgs.writeShellApplication {
          name = "db";
          # TODO: isolate pgcli config file? e.g. pspg dep...
          runtimeInputs = [
            pkgs.pgcli
            pkgs.pspg
          ];
          text = ''
            pgcli "postgresql://$SUPER_USER:$SUPER_USER_PASSWORD@localhost:$DB_PORT/$DB_NAME"
          '';
        };

        # TODO: fix this when using on-metal nix
        hot-reload = pkgs.writeShellApplication {
          name = "hot-reload";
          runtimeInputs = [ pkgs.fswatch ];
          text = pkgs.lib.strings.fileContents ./scripts/hot-reload.sh;
        };

        vm-config = import ./nix/vm-configuration.nix {
          inherit system nixpkgs;
          module = self.nixosModules.default;
        };

        openresty-dev-shell = pkgs.callPackage ./openresty/shell.nix { };
        openresty-package = pkgs.callPackage ./openresty/default.nix { };

      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            import_prod
            db
            hot-reload
            pkgs.shellcheck
            pkgs.sqitchPg
            pg

            pythonEnv
            pkgs.ruff
            pkgs.pyright
          ] ++ openresty-dev-shell.buildInputs;

          # source the .env file
          shellHook = ''
            set -a
            source .env
            set +a
          '';
        };

        apps.nixos-vm = {
          type = "app";
          program = "${vm-config.run-vm}";
        };

        packages = {
          openresty-receptdb = openresty-package;
          docker-compose-file = pkgs.writeTextFile {
            name = "docker-compose.yml";
            text = pkgs.lib.readFile ./nix/docker-compose.nixos.yml;
          };

          inherit (self.checks.${system}.default) driverInteractive;
        };

        checks.default = nixpkgs.legacyPackages."${system}".nixosTest {
          name = "Integration test of the NixOS module";
          nodes = {
            server =
              { modulesPath, ... }:
              {
                imports = [ self.nixosModules.default ];

                config = {
                  virtualisation = {
                    # 2 GiB - the project needs a little bit more space
                    diskSize = 3 * 1024;
                  };

                  services.receptdatabasen.enable = true;
                  services.receptdatabasen.jwtSecret = "3ARDEfnJWEXlnJE0GRp5NRFUiLbuNZlF";
                  services.receptdatabasen.cookieSessionSecret = "SkNUZkQNePjYlOfBbLM641wqzFhi0I7u";
                };
              };
            client =
              { pkgs, ... }:
              {
                config = {
                  environment.defaultPackages = [ pkgs.curl ];
                };
              };
          };

          testScript = { nodes }: pkgs.lib.readFile ./nix/integration_test.py;
        };
      }
    )
    // {
      nixosModules.default =
        { pkgs, ... }:
        let
          # we wrap the actual module in a new module to be able to make it platform-agnostic
          # and can access pkgs.system when referring to the self.packages
          docker-compose-file = self.packages.${pkgs.system}.docker-compose-file;
        in
        {
          # to get the actual module, we must first apply the docker-compose-file arg
          imports = [ ((import ./nix/module.nix) docker-compose-file) ];
        };
    };
}
