{
  config,
  lib,
  pkgs,
  openresty-receptdb,
  postgrest,
  postgresql,
  ...
}:
let

  cfg = config.services.receptdatabasen;
  minLengthString =
    minLength: lib.types.addCheck lib.types.str (s: lib.strings.stringLength s >= minLength);

in
{
  options.services.receptdatabasen = {
    enable = lib.mkEnableOption "Receptdatabasen service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = ''
        The internal port to run Receptdatabasen on
      '';
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "recept.axellarsson.nu";
      description = ''
        A domain to run Receptdatabasen on
        If set, the Caddy service will be configured to serve Receptdatabasen on this domain
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to open the firewall for Receptdatabasen at port 80 and 443
        This only has an effect if the domain option is set
      '';
    };

    superuserPassword = lib.mkOption {
      type = minLengthString 8;
      default = "superpassword";
      description = ''
        The password for the database `superuser` role

        Tip: use `< /dev/urandom tr -dc 'A-Za-z0-9' | head -c 32` to generate a random secret
      '';
    };

    dbPassword = lib.mkOption {
      type = minLengthString 8;
      default = "password";
      description = ''
        The password for the database user `authenticator`

        Tip: use `< /dev/urandom tr -dc 'A-Za-z0-9' | head -c 32` to generate a random secret
      '';
    };

    jwtSecret = lib.mkOption {
      type = minLengthString 32;
      example = "b6tWWsskVX6Id7LbqKWy6eHAiVumExzR";
      description = ''
        The secret to use for JWT tokens
        Must be at least 32 characters long!

        Tip: use `< /dev/urandom tr -dc 'A-Za-z0-9' | head -c 32` to generate a random secret
      '';
    };

    cookieSessionSecret = lib.mkOption {
      type = minLengthString 32;
      example = "fQGUNzfLgA6l5wMazvRcDJ2IuauIMSiR";
      description = ''
        The secret to use for cookie sessions
        Must be at least 32 characters long!

        Tip: use `< /dev/urandom tr -dc 'A-Za-z0-9' | head -c 32` to generate a random secret
      '';
    };

    imageServerSecret = lib.mkOption {
      type = minLengthString 32;
      example = "fQGUNzfLgA6l5wMazvRcDJ2IuauIMSiR";
      description = ''
        The secret to use for the image server
        Must be at least 32 characters long!

        Tip: use `< /dev/urandom tr -dc 'A-Za-z0-9' | head -c 32` to generate a random secret
      '';
    };

  };

  config = lib.mkIf cfg.enable {
    systemd.services.receptdatabasen = {
      description = "Receptdatabasen";
      wantedBy = [ "multi-user.target" ];
      environment =
        let
          rp_id = if cfg.domain != "" then cfg.domain else "localhost";
          origin =
            if cfg.domain != "" then "https://" + cfg.domain else "http://localhost:${toString cfg.port}";
        in
        {
          SUPER_USER = "superuser";
          SUPER_USER_PASSWORD = cfg.superuserPassword;
          DB_PASS = cfg.dbPassword;
          JWT_SECRET = cfg.jwtSecret;
          RP_ID = "'${rp_id}'";
          ORIGIN = "'${origin}'";

          COOKIE_SESSION_SECRET = cfg.cookieSessionSecret;
          IMAGE_SERVER_SECRET = cfg.imageServerSecret;
          OPENRESTY_PORT = toString cfg.port;
        };
      serviceConfig = {
        Type = "simple";
        User = "root";
        Restart = "on-failure";
        ExecStart = ''
          ${lib.getExe openresty-receptdb}
        '';
        ExecStop = ''
          ${lib.getExe openresty-receptdb}
        '';
      };
    };

    # Reverse proxy setup using caddy
    networking.firewall.allowedTCPPorts = lib.mkIf (cfg.domain != "" && cfg.openFirewall) [
      80
      443
    ];

    services.caddy = lib.mkIf (cfg.domain != "") {
      enable = true;

      virtualHosts."${cfg.domain}".extraConfig = ''
        reverse_proxy localhost:${toString cfg.port}
      '';
    };
  };
}
