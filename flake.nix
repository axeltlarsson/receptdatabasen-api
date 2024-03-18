{
  description = "Receptdatabasen";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        python = pkgs.python311;
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
        # );
        pythonEnv = pkgs.python311.withPackages
          (ps: [ ps.requests ps.pytest ps.webauthn soft-webauthn ]);

        pg = pkgs.postgresql_12;
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

        # nixos VM
        base = { lib, modulesPath, ... }: {
          imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];
          # https://github.com/utmapp/UTM/issues/2353
          # networking.nameservers = lib.mkIf pkgs.stdenv.isDarwin [ "8.8.8.8" ];
          networking.nameservers = [ "1.1.1.1" "9.9.9.9" "8.8.8.8" ];
          environment.defaultPackages =
            [ nixpkgs.legacyPackages.aarch64-linux.dig ];
          services.getty.autologinUser = "root";
          virtualisation = {
            graphics = false;
            host = { inherit pkgs; };
            diskSize = 2 * 1024; # 2 GiB

            # docker.daemon.settings = { dns = [ "8.8.8.8" "8.8.4.4" ]; };
            docker.extraOptions = "--dns 8.8.8.8";
            forwardPorts = [
              {
                from = "host";
                host.port = 2222;
                guest.port = 22;
              }
              {
                from = "host";
                host.port = 8080;
                guest.port = 8080;
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
            ({ config, pkgs, ... }: { services.receptdatabasen.enable = true; })
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
                  diskSize = 2
                    * 1024; # 2 GiB - the project needs a little bit more space
                  # docker.daemon.settings = { dns = [ "8.8.8.8" "8.8.4.4" ]; };
                  docker.extraOptions = "--dns 8.8.8.8";
                };

                networking.nameservers = [ "1.1.1.1" "9.9.9.9" "8.8.8.8" ];
                services.receptdatabasen.enable = true;
                # networking.firewall.allowedTCPPorts = [ 8080 53 ];
                # networking.firewall.allowedUDPPorts = [ 53 ];
                networking.firewall.enable = false;
                services.resolved.enable = true;
                services.resolved.fallbackDns =
                  [ "8.8.8.8" "2001:4860:4860::8844" ];

                environment.defaultPackages = [ pkgs.dig ];
              };
            };
            client = { pkgs, ... }: {
              config = {
                environment.defaultPackages = [ pkgs.curl pkgs.dig ];
                services.resolved.enable = true;
                services.resolved.fallbackDns =
                  [ "8.8.8.8" "2001:4860:4860::8844" ];

                networking.firewall.enable = false;
              };
            };
          };

          testScript = { nodes }:
            let
              # inherit (nodes.server.tutorial) port;
              inherit (nodes.client.nixpkgs.pkgs) curl dig;

            in ''
              import json

              start_all()

              output = server.execute("dig @8.8.8.8 ghcr.io")
              print(output)
              output = server.execute("dig example.com")
              print(output)
              output = server.execute("dig ghcr.io")
              print(output)

              output = client.execute("dig @8.8.8.8 ghcr.io")
              print(output)
              output = client.execute("dig ghcr.io")
              print(output)

              server.wait_for_unit("receptdatabasen")
              server.wait_for_open_port(8080)

              expected = {"me":{"email":"alice@email.com","user_name":"alice","id":1}}

              actual = json.loads(
                  client.wait_until_succeeds("""
                    ${curl}/bin/curl --fail --silent -H 'content-type: application/json' \
                    -d '{"user_name": "alice", "password": "pass"}' \
                    http://server:8080/rest/login
                    """,
                    5,
                  )
                )

              assert actual == expected, f"Expected {expected}, but got {actual}"
            '';
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
