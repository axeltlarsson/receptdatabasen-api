{ pkgs, ... }:
let
  # build postgres with python support and our custom python environment including webauthn
  pg-python = pkgs.python3.withPackages (ps: [ ps.webauthn ]);
  pg = pkgs.postgresql_17.override {
    pythonSupport = true;
    python3 = pg-python;
  };

in
pg
