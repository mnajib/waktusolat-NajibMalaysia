{ self }:
{ config, lib, pkgs, ... }:

# module/nixos-client.nix
#
# Enable this on every host EXCEPT the aggregator (khawlah, parang,
# bawang, ...). Runs waktusolat-fetchd in "client" role.

let
  cfg = config.services.waktusolatClient;
  system = pkgs.system;
  waktusolatPackages = self.packages.${system};
in
{
  options.services.waktusolatClient = {
    #enable = lib.mkEnableOption "waktusolat-fetchd client role";
    enable = lib.mkEnableOption "Waktu Solat Client Service (RoleType-2)";

    reminder = {
      enable = lib.mkEnableOption "system-wide waktusolat-reminder daemon (outputs to /run/waktusolat/)";
    };

    aggregatorUrl = lib.mkOption {
      type = lib.types.str;
      example = "http://nyxora:8089";
      #description = "Base URL of the waktusolat-aggregator instance on your LAN.";
      description = "RoleType-1 Aggregator HTTP URL.";
    };

    aggregatorTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Seconds to wait for the aggregator before falling back.";
    };

    zones = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "SGR01" ];
      description = "JAKIM zone codes this host needs. One fetchd and reminder instance runs per zone.";
    };

    #dataDir = lib.mkOption {
    #  type = lib.types.path;
    #  default = "/var/cache/waktusolat";
    #  description = "Directory holding <zone>.json files.";
    #};
    #
    cacheDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/cache/waktusolat";
      description = "Local cache directory for persistent storage.";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [ "SILENT" "ERROR" "WARN" "INFO" "DEBUG" ];
      default = "INFO";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.waktusolat = {
      isSystemUser = true;
      group = "waktusolat";
      #home = cfg.dataDir;
      home = cfg.cacheDir;
    };
    users.groups.waktusolat = { };

    systemd.tmpfiles.rules = [
      #"d ${cfg.dataDir} 0755 waktusolat waktusolat -"
      "d ${cfg.cacheDir} 0755 waktusolat waktusolat -"
    ];

    environment.systemPackages = [
      waktusolatPackages.render-xmobar
      waktusolatPackages.render-waybar
      waktusolatPackages.cli
    ];

    systemd.services =
      # 1. Map the Fetcher Daemons
      # 1. Fetcher & Cache Writer (LAN HTTP -> Fallback Internet -> /var/cache/waktusolat/)
      (lib.listToAttrs (map (zone: {
        #name = "waktusolat-fetchd-${zone}";
        name = "waktusolat-client-fetch-${zone}";
        value = {
          #description = "waktusolat-fetchd (client role, zone ${zone})";
          description = "Waktu Solat Client Fetcher (${zone})";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "simple";
            User = "waktusolat";
            Group = "waktusolat";
            UMask = "0022";
            ExecStart = "${waktusolatPackages.fetchd}/bin/waktusolat-fetchd ${zone}";
            Environment = [
              #"WAKTUSOLAT_DATA_DIR=${cfg.dataDir}"
              "WAKTUSOLAT_DATA_DIR=${cfg.cacheDir}"
              "WAKTUSOLAT_AGGREGATOR_URL=${cfg.aggregatorUrl}"
              "WAKTUSOLAT_AGGREGATOR_TIMEOUT=${toString cfg.aggregatorTimeout}"
              "WAKTUSOLAT_LOGLEVEL=${cfg.logLevel}"
            ];
            Restart = "on-failure";
            RestartSec = 10;
          };
        };
      }) cfg.zones))

      //

      # 2. Map the Reminder Daemons (If Enabled)
      # 2. Per-second tmpfs State Formatter (Reads /var/cache/ -> Writes /run/waktusolat/)
      (lib.listToAttrs (map (zone: {
        name = "waktusolat-reminder-${zone}";
        value = {
          #description = "waktusolat-reminder (system role, zone ${zone})";
          description = "Waktu Solat State Formatter (${zone})";
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "simple";
            # Runs in system mode targeting /run/waktusolat/
            ExecStart = "${waktusolatPackages.reminder}/bin/waktusolat-reminder --mode system --zone ${zone}";
            Restart = "always";
            RestartSec = "3";
            RuntimeDirectory = "waktusolat"; # Mounts /run/waktusolat in tmpfs

            # Use DynamicUser for security since it only writes to tmpfs
            DynamicUser = true;
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
          };
        };
      }) (if cfg.reminder.enable then cfg.zones else [])));
  };
}
