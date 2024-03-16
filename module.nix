# the first level of argument (docker-compose-file) is provided by this repo's flake
# the actual NixOS machine configuration will then pass in the actual module arguments
# that way the NixOS machine can use the module as is and doesn't have to worry about
# the docker-compose-file arg
docker-compose-file:
{ config, lib, pkgs, ... }:
let cfg = config.services.receptdatabasen;
in {
  options.services.receptdatabasen = {
    enable = lib.mkEnableOption "Receptdatabasen service";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true; # Ensure Docker service is enabled
    environment.systemPackages = with pkgs;
      [ docker-compose ]; # Ensure Docker Compose is available

    # todo: firewall
    # todo: caddy reverse proxy
    # todo: configuration, env vars for docker-compose, prod etc
    # todo: secrets

    # docker-compose script with systemd service
    systemd.services.receptdatabasen = {
      description = "Receptdatabasen";
      requires = [ "docker.service" ];
      after = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        COMPOSE_PROJECT_NAME = "receptdatabasen";
        JWT_SECRET = "so secret";
        # DB connection details (used by all containers);
        DB_PASS = "passwordpassswordpassword";
        # OpenResty;
        COOKIE_SESSION_SECRET = "secret";
        # PostgREST;
        RP_ID = "'recept.axellarsson.nu'"; # TODO: option
        ORIGIN = "'https://recept.axellarsson.nu'"; # TODO: option
        # PostgreSQL container config;
        # Use this to connect directly to the db running in the container;
        SUPER_USER = "superuser";
        SUPER_USER_PASSWORD = "superpassword";
      };
      serviceConfig = {
        Type = "simple";
        User = "root";
        Restart = "on-failure";
        ExecStart = ''
          ${pkgs.docker-compose}/bin/docker-compose -f ${docker-compose-file} up
        '';
        ExecStop = ''
          ${pkgs.docker-compose}/bin/docker-compose -f ${docker-compose-file} stop
        '';
      };
    };

    # TODO: make this work properly in a VM, somehow
    services.caddy = {
      enable = true;
      virtualHosts."localhost:1234".extraConfig = ''
        respond "hello, world"
      '';
    };

    # alternatively oci-containers for all but openresty (next step)
  };
}
