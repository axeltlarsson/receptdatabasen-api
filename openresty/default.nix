{
  pkgs,
  frontendHtml ? null,
  ...
}:

let
  # Reuse your common dependencies for Lua modules, etc.
  openresty-deps = import ./common.nix { inherit pkgs; };
in
pkgs.stdenv.mkDerivation {
  pname = "openresty-receptdb";
  version = "1.0.0";

  src = ./.;
  dontUnpack = true;

  buildInputs = [
    pkgs.openresty
    pkgs.cacert
  ] ++ openresty-deps;

  # nativeBuildInputs = [ ];

  phases = [ "installPhase" "postInstall" ];

  installPhase = ''
    # Copy the local nginx config
    mkdir -p $out/nginx/prod
    cp -r $src/nginx/* $out/nginx
    cp -r $src/nginx_prod/* $out/nginx/prod

    # Copy your local Lua sources
    mkdir -p $out/lua
    cp -r $src/lua/* $out/lua

    # Optionally embed the frontend’s built files if passed in
    ${
      if frontendHtml != null then
        ''
          mkdir -p $out/html
          cp -r ${frontendHtml}/dist/* $out/html
        ''
      else
        ""
    }
  '';

  # A final wrapper script in $out/bin to run openresty
  postInstall = ''
    mkdir -p $out/bin
    cat > $out/bin/openresty-start <<EOF
    #!/usr/bin/env bash
    set -euo pipefail

    export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

    # Start openresty, pointing to $out as the prefix
    exec ${pkgs.openresty}/bin/openresty \
      -p $out \
      -c $out/nginx/nginx.conf \
      -e /dev/stderr \
      -g "daemon off; error_log /dev/stderr debug; pid /tmp/nginx.pid;"
    EOF
    chmod +x $out/bin/openresty-start
  '';

  allowSubstitutes = true;
}
