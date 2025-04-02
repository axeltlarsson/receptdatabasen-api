{ pkgs }:
let
  openresty-deps = import ./common.nix { pkgs = pkgs; };

  op = pkgs.writeShellApplication {
    name = "op";
    runtimeInputs = [
      pkgs.cacert
      pkgs.openresty
    ];
    text = ''
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      openresty -p ./openresty -c nginx/nginx.conf -e logs/error.log -g "daemon off; error_log /dev/stderr debug; pid ./nginx.pid;"
    '';
  };

in
pkgs.mkShell {
  packages = [
    pkgs.lua-language-server
    op
    openresty-deps
  ];
}
