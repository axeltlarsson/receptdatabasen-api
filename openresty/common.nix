# common dependencies for openresty's default.nix production build and development shell.nix
{ pkgs, ... }:
let
  lua-vips = pkgs.callPackage ./lua-vips.nix {
    buildLuarocksPackage = pkgs.luajitPackages.buildLuarocksPackage;
    # openresty provides an updated version of openresty/luajit2, so we use that one
    lua = pkgs.openresty;
  };

  lua-resty-template = pkgs.callPackage ./lua-resty-template.nix {
    buildLuarocksPackage = pkgs.luajitPackages.buildLuarocksPackage;
    fetchFromGitHub = pkgs.fetchFromGitHub;
    inherit (pkgs) lib;
  };

in
[
  lua-vips
  (pkgs.luajit.withPackages (
    ps: with ps; [
      # deps for my openresty project
      lua-resty-core
      lua-resty-http
      lua-resty-jwt
      lua-resty-session
      lua-resty-template
      cjson
    ]
  ))
]
