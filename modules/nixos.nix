{ config, lib, pkgs, ... }:
let
  cfg = lib.warnIf (! isNull config.services.flatpak.uninstallUnmanagedPackages)
    "uninstallUnmanagedPackages is deprecated since nix-flatpak 0.4.0 and will be removed in 1.0.0. Use uninstallUnamanged instead."
    config.services.flatpak;
  installation = "system";
in
{
  options.services.flatpak = import ./options.nix { inherit config lib pkgs; };

  config = lib.mkIf config.services.flatpak.enable {
    systemd.services."flatpak-managed-install" = {
      # my-edit: no automatic updates at every boot/login
      # wantedBy = [
      #   "default.target" # multi-user target with a GUI. For a desktop, this is typically going to be the graphical.target
      # ];
      after = [
        "multi-user.target" # ensures that network & connectivity have been setup.
      ];
      serviceConfig = {
        Type = "oneshot"; # TODO: should this be an async startup, to avoid blocking on network at boot ?
        ExecStart = import ./installer.nix { inherit cfg pkgs lib installation; };
        # my-edit: run unit with idle scheduling policy
        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";
      };
    };
    systemd.timers."flatpak-managed-install" = lib.mkIf config.services.flatpak.update.auto.enable {
      timerConfig = {
        # my-edit: fix-following: Unit type not valid, ignoring: flatpak-managed-install
        # Unit = "flatpak-managed-install";
        OnCalendar = config.services.flatpak.update.auto.onCalendar;
        Persistent = "true";
        # my-edit
        RandomizedDelaySec = "4h";
      };
      wantedBy = [ "timers.target" ];
    };
  };
}
