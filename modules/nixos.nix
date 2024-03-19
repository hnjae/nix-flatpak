{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.flatpak;
  installation = "system";
in {
  options.services.flatpak = import ./options.nix {inherit lib pkgs;};

  config = lib.mkIf config.services.flatpak.enable {
    systemd.services."flatpak-managed-install" = {
      after = [
        "multi-user.target" # ensures that network & connectivity have been setup.
      ];
      serviceConfig = {
        Type = "oneshot"; # TODO: should this be an async startup, to avoid blocking on network at boot ?
        ExecStart = import ./installer.nix {inherit cfg pkgs lib installation;};

        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";
      };
    };
    systemd.timers."flatpak-managed-install" = lib.mkIf config.services.flatpak.update.auto.enable {
      timerConfig = {
        OnCalendar = config.services.flatpak.update.auto.onCalendar;
        Persistent = "true";
        RandomizedDelaySec = config.services.flatpak.update.auto.randomizedDelaySec;
      };
      wantedBy = ["timers.target"];
    };
  };
}
