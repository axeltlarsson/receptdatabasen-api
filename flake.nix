{
  description = "Receptdatabasen";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pyPkgs = pkgs.python311Packages;

        soft-webauthn = (pyPkgs.buildPythonPackage rec {
          pname = "soft-webauthn";
          version = "0.1.4";
          src = pkgs.fetchPypi {
            inherit pname version;
            sha256 = "sha256-6WUTNC5pu/3lpgrcsDqw1WLXDV0uIO5yA/z7308bBtA=";
          };
          doCheck = false;
          # format = "pyproject";
          propagatedBuildInputs = with pyPkgs; [ cryptography fido2 ];

          pythonImportsCheck = [ "soft_webauthn" ];
        });

        pythonEnv = pkgs.python311.withPackages
          (ps: [ ps.requests ps.pytest ps.webauthn soft-webauthn ]);

        import_prod = pkgs.writeShellApplication {
          name = "import-prod";
          runtimeInputs = [ pkgs.docker pkgs.docker-compose ];
          text = pkgs.lib.strings.fileContents ./scripts/import_prod_db.sh;
        };

        db = pkgs.writeShellApplication {
          name = "db";
          # TODO: isolate pgcli config file? e.g. pspg dep...
          runtimeInputs = [ pkgs.pgcli pkgs.pspg ];
          text = ''
            pgcli "postgresql://$SUPER_USER:$SUPER_USER_PASSWORD@localhost:$DB_PORT/$DB_NAME"
          '';
        };

        hot-reload = pkgs.writeShellApplication {
          name = "hot-reload";
          runtimeInputs = [ pkgs.fswatch ];
          text = pkgs.lib.strings.fileContents ./scripts/hot-reload.sh;
        };

        # NixOS VM
        base = { lib, modulesPath, ... }: {
          imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];
          # https://github.com/utmapp/UTM/issues/2353
          networking.nameservers = lib.mkIf pkgs.stdenv.isDarwin [ "8.8.8.8" ];
          services.getty.autologinUser = "root";
          virtualisation = {
            graphics = false;
            host = { inherit pkgs; };
            diskSize = 2 * 1024; # 2 GiB

            forwardPorts = [
              {
                from = "host";
                host.port = 8081;
                guest.port = 8081;
              }
              {
                from = "host";
                host.port = 80;
                guest.port = 80;
              }
              {
                from = "host";
                host.port = 443;
                guest.port = 443;
              }
            ];
          };
          services.openssh.enable = true;
          services.openssh.settings.PermitRootLogin = "yes";
          users.extraUsers.root.initialPassword = "";
          system.stateVersion = "24.05";
        };
        machine = nixpkgs.lib.nixosSystem {
          system = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;
          modules = [
            base
            self.nixosModules.default
            ({ config, pkgs, ... }: {
              services.receptdatabasen.enable = true;
              services.receptdatabasen.port = 8081;
              services.receptdatabasen.domain = "test.axellarsson.nu";
              services.receptdatabasen.jwtSecret =
                "3ARDEfnJWEXlnJE0GRp5NRFUiLbuNZlF";
              services.receptdatabasen.cookieSessionSecret =
                "SkNUZkQNePjYlOfBbLM641wqzFhi0I7u";
            })
          ];
        };
        program = pkgs.writeShellScript "run-vm.sh" ''
          export NIX_DISK_IMAGE=$(mktemp -u -t nixos.qcow2)
          trap "rm -f $NIX_DISK_IMAGE" EXIT
          ${machine.config.system.build.vm}/bin/run-nixos-vm
        '';

      in {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [ pkgs.bashInteractive ];
          buildInputs = [
            import_prod
            db
            hot-reload
            pkgs.shellcheck
            pkgs.sqitchPg
            pkgs.postgresql_12

            pythonEnv
            pkgs.ruff
            pkgs.ruff-lsp
            pkgs.pyright
          ];

          # source the .env file
          shellHook = ''
            set -a
            source .env
            set +a
          '';
        };

        apps.nixos-vm = {
          type = "app";
          program = "${program}";
        };

        packages = {
          docker-compose-file = pkgs.writeTextFile {
            name = "docker-compose.yml";
            text = pkgs.lib.readFile ./docker-compose.nixos.yml;
          };

          inherit (self.checks.${system}.default) driverInteractive;
        };

        checks.default = nixpkgs.legacyPackages."${system}".nixosTest {
          name = "Integration test of the NixOS module";
          nodes = {
            server = { modulesPath, ... }: {
              imports = [ self.nixosModules.default ];

              config = {
                virtualisation = {
                  # 2 GiB - the project needs a little bit more space
                  diskSize = 2 * 1024;
                };

                services.receptdatabasen.enable = true;
                services.receptdatabasen.jwtSecret =
                  "3ARDEfnJWEXlnJE0GRp5NRFUiLbuNZlF";
                services.receptdatabasen.cookieSessionSecret =
                  "SkNUZkQNePjYlOfBbLM641wqzFhi0I7u";
              };
            };
            client = { pkgs, ... }: {
              config = { environment.defaultPackages = [ pkgs.curl ]; };
            };
          };

          testScript = { nodes }: pkgs.lib.readFile ./nixos_integration_test.py;
        };
      }) // {
        nixosModules.default = { pkgs, ... }:
          let
            # we wrap the actual module in a new module to be able to make it platform-agnostic
            # and can access pkgs.system when referring to the self.packages
            docker-compose-file =
              self.packages.${pkgs.system}.docker-compose-file;
          in {
            # to get the actual module, we must first apply the docker-compose-file arg
            imports = [ ((import ./module.nix) docker-compose-file) ];
          };
      };
}
