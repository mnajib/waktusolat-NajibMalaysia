{ self }:
{ config, lib, pkgs, ... }:

# module/home-manager.nix
#
# NEW file -- xmonad-config-NajibMalaysia never had a home-manager module;
# the fetcher was spawned ad-hoc from xmonad.hs's `spawn`/`spawnOnce`. This
# module is the actual fix for the "don't fetch twice" problem.

let
  cfg = config.services.waktusolat;
  system = pkgs.system;
  waktusolatPackages = self.packages.${system};
in
{
  options.services.waktusolat = {
    enable = lib.mkEnableOption "Waktu Solat UI renderers and runtime state daemon";

    fetcher = {
      enable = lib.mkEnableOption "local fetchd (Disable this if nixos-client is handling fetches system-wide)";
    };

    zone = lib.mkOption {
      type = lib.types.str;
      default = "SGR01"; 
      description = "JAKIM zone code to fetch prayer times for.";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [ "SILENT" "ERROR" "WARN" "INFO" "DEBUG" ];
      default = "INFO";
      description = "Log verbosity for waktusolat daemons.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      waktusolatPackages.fetchd
      waktusolatPackages.render-xmobar
      waktusolatPackages.render-waybar
      waktusolatPackages.cli
    ];

    # The Singleton Fetcher (Now Optional via cfg.fetcher.enable)
    systemd.user.services.waktusolat-fetchd = lib.mkIf cfg.fetcher.enable {
      Unit = {
        Description = "waktusolat-fetchd: singleton JAKIM prayer-time fetcher (WM-agnostic)";
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

    # The 1-second state formatter daemon (User Mode)
    systemd.user.services.waktusolat-reminder = {
      Unit = {
        Description = "Waktu Solat runtime state formatter (User Mode)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };

      Service = {
        # Runs the script in user mode targeting /run/user/<UID>/waktusolat
        ExecStart = "${waktusolatPackages.reminder}/bin/waktusolat-reminder --mode user --zone ${cfg.zone}";
        Restart = "always";
        RestartSec = "3";
        RuntimeDirectory = "waktusolat"; 

        # Security constraints
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
      };
    };
  };
}
