{ nixpkgs, module, system }:
let

  pkgs = nixpkgs.legacyPackages.${system};
  # NixOS VM
  base = { lib, modulesPath, ... }: {
    imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];
    # https://github.com/utmapp/UTM/issues/2353
    networking.nameservers = lib.mkIf pkgs.stdenv.isDarwin [ "8.8.8.8" ];
    services.getty.autologinUser = "root";
    virtualisation = {
      graphics = false;
      host = { inherit pkgs; };
      diskSize = 3 * 1024; # 3 GiB

      forwardPorts = [
        {
          from = "host";
          host.port = 8081;
          guest.port = 8081;
        }
        {
          from = "host";
          host.port = 80;
          guest.port = 80;
        }
        {
          from = "host";
          host.port = 443;
          guest.port = 443;
        }
      ];
    };
    services.openssh.enable = true;
    services.openssh.settings.PermitRootLogin = "yes";
    users.extraUsers.root.initialPassword = "";
    system.stateVersion = "24.05";
  };
  machine = nixpkgs.lib.nixosSystem {
    system = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;
    modules = [
      base
      module
      ({ config, pkgs, ... }: {
        services.receptdatabasen.enable = true;
        services.receptdatabasen.port = 8081;
        services.receptdatabasen.domain = "test.axellarsson.nu";
        services.receptdatabasen.jwtSecret = "3ARDEfnJWEXlnJE0GRp5NRFUiLbuNZlF";
        services.receptdatabasen.cookieSessionSecret =
          "SkNUZkQNePjYlOfBbLM641wqzFhi0I7u";
      })
    ];
  };
  run-vm = pkgs.writeShellScript "run-vm.sh" ''
    export NIX_DISK_IMAGE=$(mktemp -u -t nixos.qcow2)
    trap "rm -f $NIX_DISK_IMAGE" EXIT
    ${machine.config.system.build.vm}/bin/run-nixos-vm
  '';
in {
  machine = machine;
  run-vm = run-vm;
}
