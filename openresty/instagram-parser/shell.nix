{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    luajit
    luajitPackages.cjson
    luajitPackages.luautf8
  ];

  shellHook = ''
    export LUA_PATH="./?.lua;$LUA_PATH"

    echo "Instagram parser development environment"
    echo "LuaJIT version: $(luajit -v)"
    echo ""
    echo "Files:"
    echo "  instagram_parser.lua - Parser module (require 'instagram_parser')"
    echo "  cli.lua              - CLI wrapper for testing"
    echo ""
    echo "Usage: cat test_curl.txt | luajit cli.lua"
    echo "   or: luajit cli.lua test_curl.txt"
  '';
}
