{ self }:
{ config, lib, pkgs, ... }:

# module/home-manager.nix
#
# NEW file -- xmonad-config-NajibMalaysia never had a home-manager module;
# the fetcher was spawned ad-hoc from xmonad.hs's `spawn`/`spawnOnce`. This
# module is the actual fix for the "don't fetch twice" problem: the daemon
# is started once by systemd at login (`WantedBy=graphical-session.target`),
# completely independent of whether xmonad, Niri, both, or neither is the
# active window manager -- so xmonad.hs and your Niri config no longer need
# to spawn or kill this process at all. They only need to run one of the
# `waktusolat-render-*` scripts to *read* the data.

with lib;
let
  cfg = config.services.waktusolat;
  system = pkgs.system;
  waktusolatPackages = self.packages.${system};
in
{
  options.services.waktusolat = {
    enable = mkEnableOption "waktusolat-fetchd, the singleton JAKIM prayer-time fetcher daemon";

    zone = mkOption {
      type = types.str;
      example = "SGR01";
      description = "JAKIM zone code to fetch prayer times for.";
    };

    logLevel = mkOption {
      type = types.enum [ "SILENT" "ERROR" "WARN" "INFO" "DEBUG" ];
      default = "INFO";
      description = "Log verbosity for waktusolat-fetchd.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      waktusolatPackages.fetchd
      waktusolatPackages.render-xmobar
      waktusolatPackages.render-waybar
      waktusolatPackages.cli
    ];

    systemd.user.services.waktusolat-fetchd = {
      Unit = {
        Description = "waktusolat-fetchd: singleton JAKIM prayer-time fetcher (WM-agnostic)";
        # CHANGED: this is the key line. Starting the daemon off
        # graphical-session.target (not xsession.target or a WM-specific
        # target) means it starts once per graphical login regardless of
        # which compositor/WM that login session is running.
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${waktusolatPackages.fetchd}/bin/waktusolat-fetchd ${cfg.zone}";
        Environment = [ "WAKTUSOLAT_LOGLEVEL=${cfg.logLevel}" ];
        Restart = "on-failure";
        RestartSec = 10;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
