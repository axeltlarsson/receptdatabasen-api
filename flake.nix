{
  description = "Receptdatabasen";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        python = pkgs.python311;
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
        # maturin_py = (
          # pyPkgs.buildPythonPackage rec {
            # pname = "maturin";
            # version = "1.4.0";
            # src = pkgs.fetchPypi {
              # inherit pname version;
              # sha256 = "sha256-7RLhdoCUp63q/Dp069uNwiAfpkxOfjHxTPxwN4v5N5A=";
              # # sha256 = pkgs.lib.fakeSha256;
            # };
            # doCheck = false;
            # # format = "pyproject";
            # propagatedBuildInputs = with pyPkgs; [
              # # typing-extensions
              # setuptools_rust
            # ];

            # pythonImportsCheck = [ "maturin" ];
          # }
        # );
        # pydantic_core_v2 = (
          # pyPkgs.buildPythonPackage rec {
            # pname = "pydantic_core";
            # version = "2.14.6";
            # src = pkgs.fetchPypi {
              # inherit pname version;
              # sha256 = "sha256-H9DB05U3KEP7oTpRwo47udWb166/6xc1j/qqHk276Ug=";
              # # sha256 = pkgs.lib.fakeSha256;
            # };
            # doCheck = false;
            # format = "pyproject";
            # propagatedBuildInputs = with pyPkgs; [
              # typing-extensions
              # maturin_py
            # ];

            # pythonImportsCheck = [ "pydantic-core" ];
          # }
        # );
        # pydantic_v2 = (
          # pyPkgs.buildPythonPackage rec {
            # pname = "pydantic";
            # version = "2.5.3";
            # src = pkgs.fetchPypi {
              # inherit pname version;
              # sha256 = "sha256-s+9XxiU1sJQWl8zmOMCJANh/y2finPqZ6KaPdH85P3o=";
            # };
            # doCheck = false;
            # format = "pyproject";
            # propagatedBuildInputs = with pyPkgs; [
              # hatchling
              # hatch-fancy-pypi-readme
              # typing-extensions
              # pydantic_core_v2
            # ];

            # pythonImportsCheck = [ "pydantic" ];
          # }
        # );
        pythonEnv = pkgs.python311.withPackages (ps: [
          ps.requests
          ps.pytest
          # (ps.webauthn.override { pydantic = pydantic_v2; })
          ps.webauthn
          soft-webauthn
        ]);

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
      in
      {

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
      });
}
