# waktusolat-NajibMalaysia

A standalone Nix Flake providing a JAKIM prayer-time fetcher daemon (waktusolat-fetchd), status-bar renderers (waktusolat-render-xmobar, waktusolat-render-waybar), and an ad-hoc CLI tool (waktusolat-cli).

Decoupled from window manager configurations (such as xmonad-config-NajibMalaysia) so that multiple WMs (e.g., xmonad, Niri) and multiple hosts across a local network share a unified fetcher architecture without duplicating requests to the JAKIM e-solat API.

## System Architecture & Data Flow

Data flows top-to-bottom from upstream API sources down to status-bar display tools:


```
                            ┌────────────────────────┐
                            │    JAKIM e-solat API   │
                            └────────────────────────┘
                                        │
                                        ▼
                      ┌─────────────────────────────────────────────────────────┐
                      │  nyxora: waktusolat-fetchd (origin role)                │
                      │  writes -> /var/lib/waktusolat/SGR01.json               │
                      │  served by Caddy -> http://nyxora:8089/SGR01.json       │
                      └─────────────────────────────────────────────────────────┘
                                        ▲                                      ▲
                                        │                                      │
                                        │ LAN HTTP                             │
                                        │                                      │
        ┌──────────────────────┬────────┴───────────────────┐                  │
        │                      │                            │                  │
        │                      │                            │                  │
  ┌─────┴───────────────┐ ┌────┴───────────┐      ┌─────────┴────────┐         │
  │khawlah              │ │parang          │      │bawang            │         │
  │(client role:        │ │(client role:   │      │(client role:     │         │
  │ask nyxora,          │ │ask nyxora,     │      │ask nyxora,       │         │
  │fall back to         │ │fall back to    │      │fall back to      │         │
  │JAKIM if away)       │ │JAKIM if away)  │      │JAKIM if away)    │         │
  └─────┬───────────────┘ └────┬───────────┘      └────────┬─────────┘         │
        │                      │                           │                   │
        │                      │                           │                   │
        │                      │                           │                   │
        ▼                      ▼                           ▼                   │
  ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐      │
  │/var/cache/          │ │/var/cache/          │ │/var/cache/          │      │
  │waktusolat/SGR01.json│ │waktusolat/SGR01.json│ │waktusolat/SGR01.json│      │
  │(shared by ALL local │ │(shared by ALL local │ │(shared by ALL local │      │
  │users on that host)  │ │users on that host)  │ │users on that host)  │      │ Direct Read
  └─────────────────────┘ └─────────────────────┘ └─────────────────────┘      │ (No network hop)
        ▲                      ▲                           ▲                   │
        │                      │                           │                   │
        │                      │                           │                   │
  ┌─────┴─────────┐       ┌────┴─────────┐        ┌────────┴───────┐      ┌────┴───────────────┐
  │Status Bar     │       │Status Bar    │        │Status Bar      │      │nyxora              │
  │Renderers:     │       │Renderers:    │        │Renderers:      │      │renderers read JSON │
  │- xmobar       │       │- xmobar      │        │- xmobar        │      │from                │
  │- waybar       │       │- waybar      │        │- waybar        │      │/var/lib/waktusolat │
  │- cli          │       │- cli         │        │- cli           │      │directly, no        │
  └───────────────┘       └──────────────┘        └────────────────┘      │network hop         │
                                                                          └────────────────────┘
```

## Host Configuration Options

### 1. Primary LAN Agrregator Node (e.g., `nyxora`)

The primary node fetches prayer times directly from JAKIM, stores the raw neutral JSON data in `/var/lib/waktusolat`, and serves it to local network peers over HTTP via Caddy.

```nix
# profiles/nixos/hosts/nyxora/services/waktusolat.nix
{ config, pkgs, inputs, ... }:

let
  waktusolatPkgs = inputs.waktusolat.packages.${pkgs.system};
in
{
  imports = [
    inputs.waktusolat.nixosModules.aggregator
  ];

  # 1. Enable the origin/aggregator daemon
  services.waktusolatAggregator = {
    enable = true;
    zones = [ "SGR01" ];
    port = 8089;
    dataDir = "/var/lib/waktusolat";
    logLevel = "INFO";
  };

  # 2. Install UI renderers and CLI tool
  environment.systemPackages = [
    waktusolatPkgs.render-xmobar
    waktusolatPkgs.render-waybar
    waktusolatPkgs.cli
  ];

  # 3. Export data path for renderers on the aggregator node
  environment.sessionVariables = {
    WAKTUSOLAT_DATA_DIR = "/var/lib/waktusolat";
    WAKTUSOLAT_ZONE = "SGR01";
  };
}
```

### 2. Satellite Client Nodes (e.g., `khawlah`, `parang`, `bawang`, ...)

Client hosts request cached prayer data from nyxora over the local network. If `nyxora` is unreachable (e.g., `parang` traveling away from home), the client automatically fails over to fetching directly from JAKIM.

```nix
# profiles/nixos/hosts/parang/services/waktusolat.nix
{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.waktusolat.nixosModules.client
  ];

  # 1. Enable client daemon with fallback
  services.waktusolatClient = {
    enable = true;
    aggregatorUrl = "http://nyxora:8089";
    zones = [ "SGR01" ];
    dataDir = "/var/cache/waktusolat";
    aggregatorTimeout = 3;
  };

  # 2. Export data path for renderers on satellite nodes
  environment.sessionVariables = {
    WAKTUSOLAT_DATA_DIR = "/var/cache/waktusolat";
    WAKTUSOLAT_ZONE = "SGR01";
  };
}
```

### 3. Using with home-manager (single-user / no multi-host, simpler)

For isolated, single-user desktop setups that do not participate in a multi-host LAN architecture:

```nix
{
  inputs.waktusolat.url = "github:NajibMalaysia/waktusolat-NajibMalaysia";

  # in your home-manager module list:
  imports = [
    inputs.waktusolat.homeManagerModules.default
  ];

  services.waktusolat = {
    enable = true;
    zone = "SGR01";
    logLevel = "INFO";
  };
}
```

## Environment Variables Reference

Renderers and daemons rely on the following environment variables:

| Variable | Description | Default Value |
|----------|-------------|---------------|
|`WAKTUSOLAT_DATA_DIR` | Path containing output `<ZONE>.json` files | `/var/cache/waktusolat` |
|`WAKTUSOLAT_ZONE` | Default JAKIM zone code to read or query | `SGR01` |
|`WAKTUSOLAT_LIB_DIR` | Directory containing library scripts | Relative script path |
|`WAKTUSOLAT_LOGLEVEL` | Logging level ( `SILENT`, `ERROR`, `WARN`, `INFO`, `DEBUG` ) | `INFO` |


## Status Bar Integrations

### xmobar Integration

Add `waktusolat-render-xmobar` as a `Run Com` plugin in your `.xmobarrc`. Set the polling interval to 10 (1 second) to drive the near-prayer-time blink effect driven by wall-clock parity (`date +%s`):

```haskell
Config {
    -- ...
    commands = [
        Run Com "waktusolat-render-xmobar" [] "waktusolat" 10
    ],
    template = "%UnsafeXMonadLog% }{ %waktusolat% | %date%"
}

```

### Waybar Integration (Niri / Hyprland)

`~/.config/waybar/config.jsonc`:

```jsonc
"custom/waktusolat": {
    "exec": "waktusolat-render-waybar",
    "return-type": "json",
    "interval": 30,
    "tooltip": true
}
```

`~/.config/waybar/style.css`:

```css
#custom-waktusolat.near {
    color: #ffbf00;
}
#custom-waktusolat.stale {
    color: #ff3333;
}
```

### Ad-hoc lookup (no daemon needed)

Query formatted prayer times directly in your terminal without invoking a status bar renderer:

```bash
waktusolat-cli SGR01
```

## Development & Testing

Enter the development environment to execute test suites and static analysis tools:

```bash
# Enter development shell
nix develop

# Run Bats unit tests
bats tests/

# Run ShellCheck on scripts
shellcheck lib/*.sh bin/*
```
