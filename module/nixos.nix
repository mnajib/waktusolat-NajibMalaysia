{ self }:
{ config, lib, pkgs, ... }:

let
  cfg = config.services.waktusolat;
  system = pkgs.system;
  waktusolatPackages = self.packages.${system};
in {
  options.services.waktusolat = {
    enable = lib.mkEnableOption "Waktu Solat prayer time management suite";

    # Top-level shared options
    zones = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "SGR01" ];
      description = "JAKIM zone codes to handle.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/cache/waktusolat";
      description = "Local persistent cache directory for prayer JSON data.";
    };

    logLevel = lib.mkOption {
      type = lib.types.str;
      default = "INFO";
      description = "Logging verbosity level (e.g. DEBUG, INFO, WARN, ERROR).";
    };

    # Client/Fallback options
    aggregatorUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://nyxora:8089";
      description = "URL of the LAN aggregator. If null, fetches directly from JAKIM.";
    };

    aggregatorTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Timeout in seconds before falling back to direct internet fetch.";
    };

    # Aggregator (RoleType-1) options
    aggregator = {
      enable = lib.mkEnableOption "HTTP LAN Aggregator service";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8089;
        description = "HTTP port to serve prayer JSON on LAN.";
      };

      openFirewallPort = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open the aggregator HTTP port in firewall.";
      };

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/waktusolat";
        description = "Primary storage directory for aggregated JSON files.";
      };
    };

    # Per-second tmpfs State Formatter options
    reminder = {
      enable = lib.mkEnableOption "Per-second tmpfs state formatter daemon (/run/waktusolat/)";
    };
  };

#-------------------------------------------------------------------------------

  config = lib.mkIf cfg.enable {
    # 1. System user setup
    users.users.waktusolat = {
      isSystemUser = true;
      group = "waktusolat";
      home = if cfg.aggregator.enable then cfg.aggregator.dataDir else cfg.dataDir;
    };
    users.groups.waktusolat = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 waktusolat waktusolat -"
    ] ++ lib.optional cfg.aggregator.enable "d ${cfg.aggregator.dataDir} 0755 waktusolat waktusolat -";

    # 2. Firewall rule
    networking.firewall.allowedTCPPorts =
      lib.optionals (cfg.aggregator.enable && cfg.aggregator.openFirewallPort) [ cfg.aggregator.port ];

    environment.systemPackages = [
      #waktusolatPackages.render-xmobar
      #waktusolatPackages.render-waybar
      #waktusolatPackages.cli
    ];

    # 3. Services setup
    systemd.services =
      # 3.1 Fetcher Service per configured zone
      (lib.listToAttrs (map (zone: {
        name = "waktusolat-fetch-${zone}";
        value = {
          description = "waktusolat-fetchd (zone ${zone})";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "simple";
            User = "waktusolat";
            Group = "waktusolat";
            UMask = "0022"; # Ensures created JSON files are 0644 (world-readable)
            ExecStart = "${waktusolatPackages.fetchd}/bin/waktusolat-fetchd ${zone}";
            Environment = [
              "WAKTUSOLAT_DATA_DIR=${if cfg.aggregator.enable then cfg.aggregator.dataDir else cfg.dataDir}"
              "WAKTUSOLAT_AGGREGATOR_TIMEOUT=${toString cfg.aggregatorTimeout}"
              "WAKTUSOLAT_LOGLEVEL=${cfg.logLevel}"
            ] ++ lib.optional (cfg.aggregatorUrl != null) "WAKTUSOLAT_AGGREGATOR_URL=${cfg.aggregatorUrl}";
            Restart = "on-failure";
            RestartSec = 10;
          };
        };
      }) cfg.zones))

      //

      # 3.2 Per-second tmpfs State Formatter (Reads local cache -> Writes /run/waktusolat/)
      #(lib.listToAttrs (map (zone: {
      #  name = "waktusolat-reminder-${zone}";
      #  value = {
      #    description = "Waktu Solat State Formatter (${zone})";
      #    wantedBy = [ "multi-user.target" ];
      #
      #    serviceConfig = {
      #      Type = "simple";
      #      ExecStart = "${waktusolatPackages.reminder}/bin/waktusolat-reminder --mode system --zone ${zone}";
      #      Restart = "always";
      #      RestartSec = "3";
      #      RuntimeDirectory = "waktusolat"; # Mounts /run/waktusolat in tmpfs
      #
      #      DynamicUser = true;
      #      NoNewPrivileges = true;
      #      ProtectSystem = "strict";
      #      ProtectHome = true;
      #    };
      #  };
      #}) (if cfg.reminder.enable then cfg.zones else [])))
      #
      # 3.2 Per-second tmpfs State Formatter (Reads local cache -> Writes /run/waktusolat/)
      (lib.listToAttrs (map (zone: {
        name = "waktusolat-reminder-${zone}";
        value = {
          description = "Waktu Solat State Formatter (${zone})";
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "simple";
            ExecStart = "${waktusolatPackages.reminder}/bin/waktusolat-reminder --mode system --zone ${zone}";
            Environment = [
              "HOME=/var/empty"
              "WAKTUSOLAT_DATA_DIR=${if cfg.aggregator.enable then cfg.aggregator.dataDir else cfg.dataDir}"
              "WAKTUSOLAT_LOGLEVEL=${cfg.logLevel}"
            ];
            Restart = "always";
            RestartSec = "3";
            RuntimeDirectory = "waktusolat"; # Mounts /run/waktusolat in tmpfs

            #DynamicUser = true;
            User = "waktusolat";
            Group = "waktusolat";

            PrivateTmp = false;
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadOnlyPaths = [
              (if cfg.aggregator.enable then cfg.aggregator.dataDir else cfg.dataDir)
            ];
          };
        };
      }) (if cfg.reminder.enable then cfg.zones else [])))

      //

      # 3.3 Light HTTP Aggregator Server (Python http.server fallback if Caddy isn't preferred)
      (lib.optionalAttrs cfg.aggregator.enable {
        waktusolat-http-server = {
          description = "Waktu Solat HTTP Aggregator Server";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "simple";
            User = "waktusolat";
            Group = "waktusolat";
            ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString cfg.aggregator.port} --directory ${cfg.aggregator.dataDir}";
            Restart = "always";
            RestartSec = 5;
          };
        };
      });
  };
}

#    services.caddy = {
#      enable = true;
#      virtualHosts."http://:${toString cfg.port}".extraConfig = ''
#        root * ${cfg.dataDir}
#        file_server browse
#        header Cache-Control "no-cache"
#      '';
#    };
#    #
#    # HTTP Server Service (Serves http://<host>:<port>/<zone>.json)
#    #systemd.services.waktusolat-http-server = {
#    #  description = "Waktu Solat HTTP Aggregator Server";
#    #  after = [ "network.target" ];
#    #  wantedBy = [ "multi-user.target" ];
#    #
#    #  serviceConfig = {
#    #    Type = "simple";
#    #    User = "waktusolat";
#    #    Group = "waktusolat";
#    #    ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString cfg.port} --directory ${cfg.dataDir}";
#    #    Restart = "always";
#    #    RestartSec = 5;
#    #  };
#    #};

