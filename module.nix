{ config, lib, pkgs, ... }: let
  cfg = config.services.receptdatabasen;
in {
  options.services.receptdatabasen = {
    enable = lib.mkEnableOption "Receptdatabasen service";
    
    dockerComposeFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [./docker-compose.yml];
      description = "List of Docker Compose files.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.docker.enable = true; # Ensure Docker service is enabled
    environment.systemPackages = with pkgs; [ dockerCompose ]; # Ensure Docker Compose is available

    # todo: firewall, caddy reverse proxy

    # docker-compose script with systemd service
    systemd.services.receptdatabasen = {
      description = "Receptdatabasen";
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      serviceConfig = {
        Type = "simple";
        User = "receptdatabasen";
        Group = "receptdatabasen";
        ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f ${lib.concatMapStringsSep " -f " toString cfg.dockerComposeFiles} up -d";
        Environment = [
          "DATABASE_URL=postgresql://${config.services.receptdatabasen.SUPER_USER}:${config.services.receptdatabasen.SUPER_USER_PASSWORD}@localhost:${config.services.receptdatabasen.DB_PORT}/${config.services.receptdatabasen.DB_NAME}"
        ];
        Restart = "on-failure";
      };
      # Note: Consider adding ExecStop for graceful shutdown
    };

    # alternatively oci-containers for all but openresty
  };
}
