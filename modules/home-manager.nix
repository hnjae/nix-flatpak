{ config, lib, pkgs, ... }@args:
let
  cfg = lib.warnIf (! isNull config.services.flatpak.uninstallUnmanagedPackages)
    "uninstallUnmanagedPackages is deprecated since nix-flatpak 0.4.0 and will be removed in 1.0.0. Use uninstallUnamanged instead."
    config.services.flatpak;
  installation = "user";
in
{

  options.services.flatpak = (import ./options.nix { inherit config lib pkgs; })
    // {
    enable = with lib; mkOption {
      type = types.bool;
      default = args.osConfig.services.flatpak.enable or false;
      description = mkDoc "Whether to enable nix-flatpak declarative flatpak management in home-manager.";
    };
  };


  config = lib.mkIf config.services.flatpak.enable {
    systemd.user.services."flatpak-managed-install" = {
      Unit = {
        After = [
          "multi-user.target" # ensures that network & connectivity have been setup.
        ];
      };
      # my-edit: no automatic updates at every boot/login
      # Install = {
      #   WantedBy = [
      #     "default.target" # multi-user target with a GUI. For a desktop, this is typically going to be the graphical.target
      #   ];
      # };
      Service = {
        Type = "oneshot"; # TODO: should this be an async startup, to avoid blocking on network at boot ?
        ExecStart = import ./installer.nix { inherit cfg pkgs lib installation; };
        # my-edit: run unit with idle scheduling policy
        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";
      };
    };

    systemd.user.timers."flatpak-managed-install" = lib.mkIf config.services.flatpak.update.auto.enable {
      Unit.Description = "flatpak update schedule";
      Timer = {
        # my-edit: fix following: Unit type not valid, ignoring: flatpak-managed-install
        # Unit = "flatpak-managed-install";
        OnCalendar = config.services.flatpak.update.auto.onCalendar;
        Persistent = "true";
        # my-edit
        RandomizedDelaySec = "4h";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # my-edit: disable home.activation (it tooks so long)
    # home.activation = {
    #   flatpak-managed-install = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    #     export PATH=${lib.makeBinPath (with pkgs; [ systemd ])}:$PATH
    #
    #     $DRY_RUN_CMD systemctl is-system-running -q && \
    #       systemctl --user start flatpak-managed-install.service || true
    #   '';
    # };

    xdg.enable = true;
  };
}
