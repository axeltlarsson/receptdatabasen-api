# dev service definition for the database
{ pkgs, ... }:
let
  db-package = pkgs.callPackage ./default.nix { };
in
{
  services.postgres."db" = {
    enable = true;
    package = db-package;
    port = 5432;
    superuser = "superuser";

    settings = {
      log_statement = "all";

      # a few settings to speed up schema reloading at the expense of durability
      fsync = "off";
      synchronous_commit = "off";
      full_page_writes = "off";
    };
    initialDatabases = [
      {
        name = "app";
        schemas = [ ./src ];
      }
    ];

  };
}
