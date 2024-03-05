{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.receptdatabasen;
in {
  options = {
    services.receptdatabasen.enable = lib.mkEnableOption "Receptdatabasen";
  };
  config = lib.mkIf cfg.enable {
    systemd.services.receptdatabasen = {
      description = "Receptdatabasen";
      wantedBy = ["multi-user.target"];
      after = ["docker.service"];
      script = ''
        docker compose -f ${./docker-compose.yml} -f ${./docker-compose.prod.yml} up -d
      '';
      serviceConfig = {
        User = "receptdatabasen";
        Group = "receptdatabasen";
        Environment = {
          "DATABASE_URL" = "postgresql://$SUPER_USER:$SUPER_USER_PASSWORD@localhost:$DB_PORT/$DB_NAME";
          "SECRET_KEY" = cfg.secretKey;
          "ALLOWED_HOSTS" = cfg.allowedHosts;
          "DEBUG" = "False";
        };
      };
    };
  };
}
