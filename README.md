# waktusolat-NajibMalaysia

JAKIM Prayer Time Aggregator, Client & State Formatter


## OVERVIEW

waktusolat-NajibMalaysia is a unified, modular NixOS suite designed to fetch, aggregate, and format JAKIM e-solat prayer times for desktop status bars (`xmobar`, `Waybar`) and CLI environments.

To minimize WAN traffic and prevent redundant API queries to JAKIM, the system supports a 2-tier architecture (Aggregator and Client). All 1-second state updates for desktop status bars are written strictly to RAM disk (`tmpfs`) to prevent SSD wear.


## FEATURES

1. Zero SSD Wear (RAM Disk Engine)
   - All continuous 1-second state updates (JSON, CLI, xmobar TXT, Waybar HTML) are written strictly to RAM disk (`tmpfs` at `/run/waktusolat/`).
   - The primary prayer data on physical disk is only updated when new schedules are fetched (typically once per day), eliminating continuous disk write cycles and preserving drive longevity.

2. Efficient LAN Aggregation
   - `nyxora` acts as the single primary origin node, fetching directly from JAKIM e-solat.
   - Client workstation nodes (`asmak`, `khawlah`, etc.) query `nyxora` over HTTP, drastically reducing external WAN queries and preventing redundant API traffic.

3. Seamless Offline / WAN Fallback
   - Client fetchers automatically fall back to direct JAKIM API calls if the LAN aggregator is unreachable (e.g., laptop traveling outside the home LAN).

4. Pure Declarative NixOS Architecture
   - Unified `services.waktusolat.*` options automatically configure systemd units, file paths, and local web servers without requiring complex symlinks or manual path handling.

5. Adaptive Exponential Backoff & Jitter Fallback
   - Direct JAKIM fetch failures use an adaptive retry schedule starting at 30 seconds and exponentially doubling up to 15 minutes ($30\text{s} \to 60\text{s} \to 120\text{s} \dots \text{max } 15\text{m}$).
   - Includes 1–10s randomized jitter to prevent API stampedes/collisions during connection recoveries.
   - Automatically resets to the normal 3-hour interval on the next successful refresh.

6. Visual Stale Data Indication (OLD Badge)
   - When network connectivity fails or JAKIM is unreachable, waktusolat-fetchd falls back to cached backup data and sets "is_stale": true.
   - waktusolat-reminder automatically injects a highlighted OLD badge into status bars (xmobar, Waybar) and CLI outputs to visually notify you that prayer times are served from stale cache.


## Architecture & Data Flow

### [RoleType-1: Aggregator Node (e.g., `nyxora`)]
  1. `systemd` service (`waktusolat-fetch-<zone>`) fetches prayer data from JAKIM.
  2. Saves master JSON to: `/var/lib/waktusolat/<ZONE>.json`
  3. Built-in Python 3 HTTP server exposes data on LAN:
     `http://<aggregator-host>:8089/<ZONE>.json`

### [RoleType-2: Client Node (e.g., `asmak`)]
  1. `systemd` service (`waktusolat-fetch-<zone>`) attempts LAN fetch from
     Aggregator first (`http://nyxora:8089`).
  2. Falls back to direct JAKIM fetch if the Aggregator is unreachable.
  3. Writes persistent local cache to: `/var/cache/waktusolat/<ZONE>.json`
  4. `systemd` service (`waktusolat-reminder-<zone>`) reads local cache every
     second and updates `tmpfs`:
     - `/run/waktusolat/reminder.json`
     - `/run/waktusolat/reminder.cli`
     - `/run/waktusolat/reminder.txt`   (xmobar markup)
     - `/run/waktusolat/reminder.html`  (Waybar / Pango markup)

### [UI Layer (xmobar / Waybar)]
  - Status bars perform a lightweight 'cat' on `/run/waktusolat/reminder.{txt,html}`
    every second.


```
                            ┌────────────────────────┐
                            │    JAKIM e-solat API   │
                            └────────────────────────┘
                                        │
                                        ▼
                      ┌──────────────────────────────────────────────────────────┐
                      │      Server/Aggregator Node                              │
                      │                                                          │
                      │  1. waktusolat-fetch-SGR01 service pulls data from JAKIM.│
                      │  2. Writes -> /var/lib/waktusolat/SGR01.json             │
                      │     • Storage Media: Disk (NVMe / SSD)                   │
                      │     • Write Cadence: ~1x / day (On schedule fetch)       │
                      │     • Reason: Persistent primary storage for LAN service │
                      │  3. Served via Python 3 -> http://nyxora:8089/SGR01.json │
                      │                                                          │
                      │  Local Reminder Loop (Direct local read):                │
                      │  waktusolat-reminder-SGR01                               │
                      └──────────────────────────────────────────────────────────┘
                                        ▲
                                        │
                                        │ LAN HTTP
                                        │ (Fallback: Direct WAN to JAKIM API)
                                        │
                               ┌─────────────────┐
                               │   Client Node   │
                               └────────┬────────┘
                                        │
                                        ▼
                           ┌─────────────────────────┐
                           │ Persistent Local Cache  │
                           │ /var/cache/waktusolat/  │
                           │ SGR01.json              │
                           └────────────┬────────────┘
                                        │ • Storage Media: Disk (NVMe / SSD)
                                        │ • Write Cadence: ~1x / day
                                        │ • Reason: Offline resilience across reboots
                                        │
                                        ▼
                           ┌─────────────────────────┐
                           │ waktusolat-reminder     │
                           │ (Per-Second State Loop) │
                           │ Reads JSON into memory  │
                           └────────────┬────────────┘
                                        │
                                        ▼
    ┌───────────────────────────────────────────────────────────────────────┐
    │ RAM Disk (tmpfs)                                                      │
    │ /run/waktusolat/                                                      │
    │ - reminder.json                                                       │
    │ - reminder.cli                                                        │
    │ - reminder.txt (xmobar)                                               │
    │ - reminder.html (waybar)                                              │
    ├───────────────────────────────────────────────────────────────────────┤
    │ • Storage Media: RAM Disk (tmpfs)                                     │
    │ • Write Cadence: Every 1 second                                       │
    │ • Reason: ZERO SSD wear for high-frequency status bar updates         │
    └───────────────────────────────────┬───────────────────────────────────┘
                                        │
                                        ▼
                           ┌─────────────────────────┐
                           │ Status Bar Renderers    │
                           │ - xmobar (cat .txt)     │
                           │ - waybar (cat .html)    │
                           │ - cli    (cat .cli)     │
                           └─────────────────────────┘
```


## Host Configuration Options

### 1. Primary LAN Aggregator Node (e.g., `nyxora`)

The primary node fetches prayer times directly from JAKIM, stores the raw neutral JSON data in `/var/lib/waktusolat`, and serves it to local network peers over HTTP via Python 3 HTTP server.

```nix
# profiles/nixos/hosts/nyxora/services/waktusolat.nix
{ config, inputs, ... }:

{
  imports = [
    inputs.waktusolat.nixosModules.default
  ];

  services.waktusolat = {
    enable = true;
    zones = [ "SGR01" ];

    aggregator = {
      enable = true;
      openFirewallPort = true;
    };

    reminder.enable = false;
  };

}
```

### 2. Satellite Client Nodes (e.g., `khawlah`, `parang`, `bawang`, ...)

Client hosts request cached prayer data from nyxora over the local network. If `nyxora` is unreachable (e.g., `parang` traveling away from home), the client automatically fails over to fetching directly from JAKIM.

```nix
# profiles/nixos/hosts/parang/services/waktusolat.nix
{ config, inputs, ... }:

{
  imports = [
    #Import the unified module in your NixOS configuration:
    inputs.waktusolat.nixosModules.default
  ];

  services.waktusolat = {
    enable = true;
    zones = [ "SGR01" ];

    aggregatorUrl = "http://nyxora:8089";

    reminder.enable = true;          # Enables per-second /run/waktusolat/ daemon
  };

}
```

### 3. Using with home-manager (single-user / no multi-host, simpler)

For isolated, single-user desktop setups that do not participate in a multi-host LAN architecture, operating in user-session space:

```nix
{ config, inputs, ... }:
{

  # in your home-manager module list:
  imports = [
    inputs.waktusolat.homeManagerModules.default
  ];

  services.waktusolat = {
    enable = true;
    zone = "SGR01";

    # Disable fetcher if system-level NixOS client/aggregator is active
    fetcher.enable = false;

    reminder.enable = true;
  };

}
```


## Summary

### Directory & Storage Summary

| Directories | Description |
|---------------------------|---------------------------------------------------------|
|`/var/lib/waktusolat/`|          Aggregator primary persistent storage (Disk)|
|`/var/cache/waktusolat/` |        Client local persistent cache (Disk)|
|`/run/waktusolat/` |              System-level 1-second state files (RAM / tmpfs)|
|`/run/user/<UID>/waktusolat/`|   User-level 1-second state files (RAM / tmpfs)|

### Binaries & Utilities

| Tools | Description |
|---------------------------|---------------------------------------------------------|
| `waktusolat-fetchd`         | Fetcher daemon (LAN aggregator primary, JAKIM fallback) |
| `waktusolat-reminder`       |    1-second loop state formatter (JSON, CLI, TXT, HTML) |
| `waktusolat-cli`             |   CLI tool to display prayer times directly in shell |
| `waktusolat-render-xmobar`    |  xmobar renderer wrapper |
| `waktusolat-render-waybar`     | Waybar renderer wrapper |

### Environment Variables Reference

Renderers and daemons rely on the following environment variables:

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `WAKTUSOLAT_AGGREGATOR_URL` | Aggregator endpoint (e.g., http://nyxora:8089). Unset = origin role. | "" (origin) |
| `WAKTUSOLAT_AGGREGATOR_TIMEOUT` | LAN Aggregator HTTP request timeout in seconds | 3 |
|`WAKTUSOLAT_DATA_DIR` | Path containing output `<ZONE>.json` files | `/var/cache/waktusolat` |
|`WAKTUSOLAT_ZONE` | Default JAKIM zone code to read or query | `SGR01` |
|`WAKTUSOLAT_LIB_DIR` | Directory containing library scripts | Relative script path |
|`WAKTUSOLAT_LOGLEVEL` | Logging level ( `SILENT`, `ERROR`, `WARN`, `INFO`, `DEBUG` ) | `INFO` |


## VERIFICATION & DIAGNOSTICS

```Bash
Check fetcher service status:
  $ systemctl status waktusolat-fetch-SGR01.service

Check HTTP aggregator status (on aggregator node):
  $ systemctl status waktusolat-http-server.service

Check reminder formatter status:
  $ systemctl status waktusolat-reminder-SGR01.service

Monitor real-time state updates in tmpfs:
  $ watch -n 1 cat /run/waktusolat/reminder.txt
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

## Documentation

Additional guides and detailed module option references are available in the [`docs/`](./docs) directory:

* **[NixOS Options (`docs/NIXOS-OPTIONS.md`)](./docs/NIXOS-OPTIONS.md)**  
  Complete reference for all system-level NixOS module options, including daemon configurations, HTTP LAN aggregator settings, and satellite client controls.

* **[Home Manager Options (`docs/HOME-MANAGER-OPTIONS.md`)](./docs/HOME-MANAGER-OPTIONS.md)**  
  Detailed option listings for single-user environment management under Home Manager.

* **[Status Bar Integrations (`docs/STATUS-BAR-INTEGRATIONS.md`)](./docs/STATUS-BAR-INTEGRATIONS.md)**  
  Setup guides and script integration examples for status bars like XMobar and Waybar.
