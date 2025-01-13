# Derivation for openresty-receptdb
# Packages openresty with the local nginx config and Lua sources in the repo
# optionally embeds the frontend’s built files if passed in as the frontendHtml argument
{
  pkgs,
  lib,
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

  phases = [
    "installPhase"
    "postInstall"
  ];

  installPhase = ''
    # Copy the local nginx config
    mkdir -p $out/nginx/prod
    cp -r $src/nginx/* $out/nginx
    cp -r $src/nginx_prod/* $out/nginx/prod

    # Copy the local Lua sources
    mkdir -p $out/lua
    cp -r $src/lua/* $out/lua

    # vendor 3:rd party deps for openresty
    # the 3:rd party lua deps in buildinputs are not immediately available to openresty
    # e.g. they are put in /nix/store/pc74phsphpjrqy0cia0nkcg7r6s7nz0h-luajit2.1-lua-vips-1.1-11/
    # which is not by default included in LUA_PATH
    # let's vendor them and in the wrapper script set LUA_PATH to include them
    # (we could skip the vendoring step here and just point LUA_PATH to the buildinputs directly, but this is cleaner)
    mkdir -p $out/lua/vendor
    ${lib.concatMapStringsSep "\n" (dep: ''
      cp -r ${dep}/share/lua/5.1/* $out/lua/vendor
    '') openresty-deps}

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

  # A final wrapper script in $out/bin to run openresty for this app
  postInstall = ''
    mkdir -p $out/bin
    cat > $out/bin/openresty-receptdb <<EOF
    #!/usr/bin/env bash
    set -euo pipefail

    export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

    # set up the LUA_PATH to include the vendored 3:rd party dependencies
    export LUA_PATH="$out/lua/vendor/?.lua;$out/lua/vendor/?/init.lua;$LUA_PATH"

    # Start openresty, pointing to $out as the prefix
    exec ${pkgs.openresty}/bin/openresty \
      -p $out \
      -c $out/nginx/nginx.conf \
      -e /dev/stderr \
      -g "daemon off; error_log /dev/stderr debug; pid /tmp/nginx.pid;"
    EOF
    chmod +x $out/bin/openresty-receptdb
  '';

  allowSubstitutes = true;
}
