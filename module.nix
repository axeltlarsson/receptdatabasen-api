# the first level of argument (docker-compose-file) is provided by this repo's flake
# the actual NixOS machine configuration will then pass in the actual module arguments
# that way the NixOS machine can use the module as is and doesn't have to worry about
# the docker-compose-file arg
docker-compose-file:
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.receptdatabasen;
in {
  options.services.receptdatabasen = {
    enable = lib.mkEnableOption "Receptdatabasen service";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true; # Ensure Docker service is enabled
    environment.systemPackages = with pkgs; [docker-compose]; # Ensure Docker Compose is available

    # todo: firewall
    # todo: caddy reverse proxy
    # todo: configuration, env vars for docker-compose, prod etc

    # docker-compose script with systemd service
    systemd.services.receptdatabasen = {
      description = "Receptdatabasen";
      after = ["docker.service"];
      wants = ["docker.service"];
      wantedBy = ["multi-user.target"];
      script = ''
        ${pkgs.docker-compose}/bin/docker-compose -f ${docker-compose-file} up -d
      '';
      preStop = ''
        ${pkgs.docker-compose}/bin/docker-compose -f ${docker-compose-file} stop
      '';
      serviceConfig = {
        Type = "simple";
        User = "root";
        # Consider setting specific capabilities or sandboxing options here if necessary
      };
    };

    # alternatively oci-containers for all but openresty (next step)
  };
}
