{
  description = "Receptdatabasen";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      services-flake,
      process-compose-flake,
      nix-filter,
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
          # For integration tests we create a python env with the necessary dependencies
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
              pkgs.postgresql_17
            ];
            text = pkgs.lib.strings.fileContents ./scripts/import_prod_db.sh;
          };

          db = pkgs.writeShellApplication {
            name = "db";
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
              pkgs.postgresql_17
            ];
            text = pkgs.lib.strings.fileContents ./scripts/hot-reload.sh;
          };

          vm-config = import ./nix/vm-configuration.nix {
            inherit system nixpkgs;
            module = self.nixosModules.default;
          };

          frontend-dev-shell = pkgs.callPackage ./frontend/shell.nix { };
          frontend-dist =
            (pkgs.callPackage ./frontend/default.nix {
              inherit (pkgs) cacert;
              elm = pkgs.elmPackages.elm;
              elm-test = pkgs.elmPackages.elm-test;
              uglify-js = pkgs.nodePackages.uglify-js;
              nix-filter = nix-filter.lib;
            }).frontend;

            openresty-dev-shell = pkgs.callPackage ./openresty/shell.nix { };
            openresty-package = pkgs.callPackage ./openresty/default.nix { frontendHtml = frontend-dist; };
        in
        {
          devShells.default = pkgs.mkShell {
            buildInputs = [
              # db
              import-prod
              db
              pkgs.sqitchPg

              # top-level
              pythonEnv
              pkgs.ruff
              pkgs.pyright
              hot-reload
              pkgs.shellcheck

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
            openresty-receptdb = {
              type = "app";
              program = "${openresty-package}/bin/openresty-receptdb";
            };
          };

          packages = {
            frontend-dist = frontend-dist;
            openresty-receptdb = openresty-package;
            docker-compose-file = pkgs.writeTextFile {
              name = "docker-compose.yml";
              text = pkgs.lib.readFile ./nix/docker-compose.nixos.yml;
            };

            inherit (self.checks.${system}.default) driverInteractive;
          };

          formatter = pkgs.nixfmt-rfc-style;

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
              imports = [
                services-flake.processComposeModules.default
                # db is in its own module
                ./db/service.nix
              ];
              settings.processes = {
                # since this is "dev" we use the dev versions - not the "production" built derivations like (${self'.apps.openresty-receptdb.program})
                postgrest = {
                  command = "postgrest";
                  depends_on."db".condition = "process_healthy";
                };
                openresty-receptdb = {
                  command = "op";
                  depends_on."db".condition = "process_healthy";
                };
                frontend.command = "(cd frontend; npm run start)";
                hot-reload = {
                  command = "hot-reload";
                  depends_on."postgrest".condition = "process_started";
                  depends_on."db".condition = "process_started";
                  depends_on."openresty-receptdb".condition = "process_started";
                };
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
