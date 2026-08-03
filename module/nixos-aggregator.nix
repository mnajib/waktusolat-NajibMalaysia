{ self }:
{ config, lib, pkgs, ... }:

# module/nixos-aggregator.nix
#
# NEW. Enable this on exactly ONE host on your home network (nyxora, per
# your setup) -- it's the only host that should ever talk to JAKIM
# directly. Runs waktusolat-fetchd in "origin" role (no
# WAKTUSOLAT_AGGREGATOR_URL set) and serves the resulting JSON over HTTP via
# Caddy, so every other host's client-role fetchd (module/nixos-client.nix)
# can read it instead of hitting JAKIM itself.
#
# This is a NixOS system module, not a home-manager module: it needs its
# own dedicated system user so the data it writes is readable by every
# local user on the host, not scoped to whichever user happened to log in
# first.

with lib;
let
  cfg = config.services.waktusolatAggregator;
  system = pkgs.system;
  waktusolatPackages = self.packages.${system};
in
{
  options.services.waktusolatAggregator = {
    enable = mkEnableOption "waktusolat-aggregator: the single JAKIM-facing fetcher + LAN HTTP server for this network";

    zones = mkOption {
      type = types.listOf types.str;
      default = [ "SGR01" ];
      example = [ "SGR01" "WLY01" ];
      description = ''
        JAKIM zone codes to fetch and serve. One waktusolat-fetchd instance
        (origin role) runs per zone listed here.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 8089;
      description = "Port Caddy listens on for serving <zone>.json files.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/waktusolat";
      description = "Directory holding <zone>.json files, served read-only over HTTP.";
    };

    logLevel = mkOption {
      type = types.enum [ "SILENT" "ERROR" "WARN" "INFO" "DEBUG" ];
      default = "INFO";
    };
  };

  config = mkIf cfg.enable {
    users.users.waktusolat = {
      isSystemUser = true;
      group = "waktusolat";
      home = cfg.dataDir;
    };
    users.groups.waktusolat = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 waktusolat waktusolat -"
    ];

    # One origin-role fetchd instance per configured zone.
    systemd.services = listToAttrs (map
      (zone: {
        name = "waktusolat-fetchd-${zone}";
        value = {
          description = "waktusolat-fetchd (origin role, zone ${zone})";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "simple";
            User = "waktusolat";
            Group = "waktusolat";
            ExecStart = "${waktusolatPackages.fetchd}/bin/waktusolat-fetchd ${zone}";
            Environment = [
              "WAKTUSOLAT_DATA_DIR=${cfg.dataDir}"
              "WAKTUSOLAT_LOGLEVEL=${cfg.logLevel}"
              # WAKTUSOLAT_AGGREGATOR_URL intentionally unset -> origin role
            ];
            Restart = "on-failure";
            RestartSec = 10;
          };
        };
      })
      cfg.zones);

    services.caddy = {
      enable = true;
      virtualHosts."http://:${toString cfg.port}".extraConfig = ''
        root * ${cfg.dataDir}
        file_server browse
        header Cache-Control "no-cache"
      '';
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
