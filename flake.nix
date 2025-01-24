{
  description = "Receptdatabasen";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs_24_05.url = "github:NixOS/nixpkgs/nixpkgs-24.05-darwin";
    flake-parts.url = "github:hercules-ci/flake-parts";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs_24_05,
      flake-parts,
      services-flake,
      process-compose-flake,
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ process-compose-flake.flakeModule ];
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      perSystem =
        {
          config,
          self',
          pkgs,
          lib,
          system,
          ...
        }:
        let
          # build postgres with python support and our custom python environment including webauthn
          pg-python = pkgs.python3.withPackages (ps: [ ps.webauthn ]);
          pg = pkgs.postgresql_17.override {
            pythonSupport = true;
            python3 = pg-python;
          };

          py-pkgs = pkgs.python311Packages;

          soft-webauthn = py-pkgs.buildPythonPackage rec {
            pname = "soft-webauthn";
            version = "0.1.4";
            src = pkgs.fetchPypi {
              inherit pname version;
              sha256 = "sha256-6WUTNC5pu/3lpgrcsDqw1WLXDV0uIO5yA/z7308bBtA=";
            };
            doCheck = false;
            # format = "pyproject";
            propagatedBuildInputs = with py-pkgs; [
              cryptography
              fido2
            ];

            pythonImportsCheck = [ "soft_webauthn" ];
          };
          pythonEnv = pkgs.python311.withPackages (ps: [
            ps.requests
            ps.pytest
            ps.webauthn
            soft-webauthn
          ]);

          import-prod = pkgs.writeShellApplication {
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

          hot-reload = pkgs.writeShellApplication {
            name = "hot-reload";
            runtimeInputs = [
              pkgs.fswatch
              pkgs.jq
            ];
            text = pkgs.lib.strings.fileContents ./scripts/hot-reload.sh;
          };

          vm-config = import ./nix/vm-configuration.nix {
            inherit system nixpkgs;
            module = self.nixosModules.default;
          };

          openresty-dev-shell = pkgs.callPackage ./openresty/shell.nix { };
          openresty-package = pkgs.callPackage ./openresty/default.nix { };

          frontend-dev-shell = import ./frontend/shell.nix { inherit system; };
        in
        {
          devShells.default = pkgs.mkShell {
            buildInputs = [
              import-prod
              db
              hot-reload
              pkgs.shellcheck
              pkgs.sqitchPg
              pg

              pythonEnv
              pkgs.ruff
              pkgs.pyright
              pkgs.postgrest
            ];

            inputsFrom = [
              openresty-dev-shell
              frontend-dev-shell
            ];

            # source the .env file
            shellHook = ''
              set -a
              source .env
              set +a
            '';
          };

          apps = {
            nixos-vm = {
              type = "app";
              program = "${vm-config.run-vm}";
            };
            postgrest = {
              type = "app";
              program = "${pkgs.postgrest}/bin/postgrest";
            };
            openresty-receptdb = {
              type = "app";
              program = "${openresty-package}/bin/openresty-receptdb";
            };
          };

          packages = {
            openresty-receptdb = openresty-package;
            docker-compose-file = pkgs.writeTextFile {
              name = "docker-compose.yml";
              text = pkgs.lib.readFile ./nix/docker-compose.nixos.yml;
            };

            inherit (self.checks.${system}.default) driverInteractive;
          };

          # TODO: can probably do pkgs.nixosTest directly
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
          process-compose."dev" =
            { config, ... }:
            {
              imports = [ services-flake.processComposeModules.default ];
              services.postgres."db" = {
                enable = true;
                package = pg;
                port = 5432;
                superuser = "superuser";

                settings = {
                  log_statement = "all";
                
                  # a few settings to speed up schema reloading at the expense of durability
                  fsync = "off";
                  synchronous_commit = "off";
                  full_page_writes = "off";
                };
                initialDatabases = [
                  {
                    name = "app";
                    schemas = [ ./db/src ];
                  }
                ];

              };
              # TODO: dependencies - postgrest and openresty depends on healthy db being up
              settings.processes = {
                # since this is "dev" we use the dev versions - not the "production" built derivations like (${self'.apps.openresty-receptdb.program})
                postgrest.command = "postgrest";
                openresty-receptdb.command = "op";
                frontend.command = "(cd frontend; npm run start)";
              };
            };

        };
      flake.nixosModules = {
        default =
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
    };
}
