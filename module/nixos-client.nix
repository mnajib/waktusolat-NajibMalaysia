{ self }:
{ config, lib, pkgs, ... }:

# module/nixos-client.nix
#
# NEW. Enable this on every host EXCEPT the aggregator (khawlah, parang,
# bawang, ...). Runs waktusolat-fetchd in "client" role: each cycle it asks
# the aggregator over the LAN first, and only falls back to a direct JAKIM
# fetch if the aggregator can't be reached -- e.g. parang away from the
# home network. Either way, the result lands in the same
# <dataDir>/<zone>.json, so waktusolat-render-xmobar/-waybar don't need to
# know which path was taken.
#
# Also a NixOS system module rather than home-manager, for the same reason
# as nixos-aggregator.nix: the data should be shared by every local Unix
# user on the host, not scoped to one user's session.

with lib;
let
  cfg = config.services.waktusolatClient;
  system = pkgs.system;
  waktusolatPackages = self.packages.${system};
in
{
  options.services.waktusolatClient = {
    enable = mkEnableOption "waktusolat-fetchd client role: prefers the LAN aggregator, falls back to JAKIM directly";

    aggregatorUrl = mkOption {
      type = types.str;
      example = "http://nyxora:8089";
      description = "Base URL of the waktusolat-aggregator instance on your LAN.";
    };

    aggregatorTimeout = mkOption {
      type = types.ints.positive;
      default = 3;
      description = ''
        Seconds to wait for the aggregator before falling back to a direct
        JAKIM fetch. Keep this short -- it's on the hot path of every fetch
        cycle, and a host that's genuinely away from the LAN (e.g. parang
        traveling) should fail over quickly rather than stall.
      '';
    };

    zones = mkOption {
      type = types.listOf types.str;
      default = [ "SGR01" ];
      description = "JAKIM zone codes this host needs. One fetchd instance runs per zone.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/cache/waktusolat";
      description = ''
        Directory holding <zone>.json files, world-readable so every local
        user's xmobar/Waybar renderer can read it regardless of which Unix
        user is running the bar.
      '';
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

    environment.systemPackages = [
      waktusolatPackages.render-xmobar
      waktusolatPackages.render-waybar
      waktusolatPackages.cli
    ];

    systemd.services = listToAttrs (map
      (zone: {
        name = "waktusolat-fetchd-${zone}";
        value = {
          description = "waktusolat-fetchd (client role, zone ${zone})";
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
              "WAKTUSOLAT_AGGREGATOR_URL=${cfg.aggregatorUrl}"
              "WAKTUSOLAT_AGGREGATOR_TIMEOUT=${toString cfg.aggregatorTimeout}"
              "WAKTUSOLAT_LOGLEVEL=${cfg.logLevel}"
            ];
            Restart = "on-failure";
            RestartSec = 10;
          };
        };
      })
      cfg.zones);

    # NOTE: renderers read WAKTUSOLAT_DATA_DIR / WAKTUSOLAT_ZONE from the
    # environment. Since renderers are invoked per-user by xmobar/Waybar
    # (not as a systemd service), set these in the user's session, e.g. in
    # home-manager's `home.sessionVariables`:
    #   WAKTUSOLAT_DATA_DIR = "/var/cache/waktusolat";
    #   WAKTUSOLAT_ZONE = "SGR01";
  };
}
