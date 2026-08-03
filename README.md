# waktusolat-NajibMalaysia

JAKIM prayer-time fetcher + status-bar renderers, as a standalone Nix flake.

Split out of `xmonad-config-NajibMalaysia` so that xmonad and Niri (or any
other WM) can share **one** fetcher process instead of each running its own
copy against the JAKIM API.

## Architecture

```
                         systemd --user
                  ┌───────────────────────────┐
                  │ waktusolat-fetchd.service │  <-- ONE instance, WM-agnostic
                  └────────────┬──────────────┘
                               │ writes
                               ▼
       ┌────────────────────────────────────────────────────────────────┐
       │   /tmp/$USER-waktusolat-data.json   (neutral JSON, no markup)  │
       └────────────────────────────────────────────────────────────────┘
                     ▲                        ▲
                     │ reads                  │ reads
        ┌────────────┴───────────┐  ┌─────────┴──────────────┐
        │ waktusolat-render-     │  │ waktusolat-render-     │
        │ xmobar                 │  │ waybar                 │
        └────────────┬───────────┘  └─────────┬──────────────┘
                     │                        │
                     ▼                        ▼
                   xmobar                  Waybar (Niri)
```

`waktusolat-fetchd` is guarded by `flock` (`/tmp/$USER-waktusolat-fetchd.lock`)
as a belt-and-braces safety net, but the real fix is that it's started once
by `systemd --user`, `WantedBy=graphical-session.target` -- neither xmonad
nor Niri need to spawn or kill it.

## Multi-host setup (NEW)

Instead of every host being its own JAKIM client, exactly ONE host (your
home server, `nyxora`) fetches from JAKIM and serves the result over your
LAN. Every other host asks `nyxora` first, and only falls back to fetching
JAKIM directly if `nyxora` is unreachable (e.g. `parang` away from home).

```
                            ┌────────────────────────┐
                            │    JAKIM e-solat API   │
                            └────────────────────────┘
                                        │
                                        ▼
                  ┌─────────────────────────────────────────────────────┐
                  │  nyxora: waktusolat-fetchd (origin role)            │
                  │  writes -> /var/lib/waktusolat/SGR01.json           │
                  │  served by Caddy -> http://nyxora:8089/SGR01.json   │
                  └─────────────────────────────────────────────────────┘
                                        │
                                        │ LAN
                                        │
        ┌───────────────┬───────────────┼───────────────┐
        │               │               │               │
        ▼               ▼               ▼               ▼
  ┌───────────────┐ ┌──────────────┐ ┌──────────────┐ ┌───────────────────┐
  │khawlah        │ │parang        │ │bawang        │ │nyxora             │
  │(client role:  │ │(client role: │ │(client role: │ │(renderers read    │
  │ask nyxora,    │ │ask nyxora,   │ │ask nyxora,   │ │/var/lib/waktusolat│
  │fall back to   │ │fall back to  │ │fall back to  │ │directly, no       │
  │JAKIM if away) │ │JAKIM if away)│ │JAKIM if away)│ │network hop)       │
  └───────────────┘ └──────────────┘ └──────────────┘ └───────────────────┘
        │               │               │
        │               │               │
        │               │               ▼
        │               │           ┌────────────────────────────────────────────────────────────────────────────┐
        │               │           │ /var/cache/waktusolat/SGR01.json  (shared by ALL local users on that host) │
        │               ▼           └────────────────────────────────────────────────────────────────────────────┘
        │           ┌────────────────────────────────────────────────────────────────────────────┐
        │           │ /var/cache/waktusolat/SGR01.json  (shared by ALL local users on that host) │
        ▼           └────────────────────────────────────────────────────────────────────────────┘
   ┌────────────────────────────────────────────────────────────────────────────┐
   │ /var/cache/waktusolat/SGR01.json  (shared by ALL local users on that host) │
   └────────────────────────────────────────────────────────────────────────────┘
```

### On `nyxora` (the aggregator)

```nix
{
  imports = [ inputs.waktusolat.nixosModules.aggregator ];
  services.waktusolatAggregator = {
    enable = true;
    zones = [ "SGR01" ];
    port = 8089;
  };
}
```

### On every other host (`khawlah`, `parang`, `bawang`, ...)

```nix
{
  imports = [ inputs.waktusolat.nixosModules.client ];
  services.waktusolatClient = {
    enable = true;
    aggregatorUrl = "http://nyxora:8089";
    zones = [ "SGR01" ];
  };

  # renderers need to know where to look -- set per-user or system-wide:
  environment.sessionVariables = {
    WAKTUSOLAT_DATA_DIR = "/var/cache/waktusolat";
    WAKTUSOLAT_ZONE = "SGR01";
  };
}
```

`parang`'s `waktusolat-fetchd` will happily fetch JAKIM directly whenever
`nyxora` can't be reached (e.g. traveling) -- no manual intervention needed,
and it re-syncs with `nyxora` automatically once back on the home LAN
(aggregator polling interval: 5 minutes).

## Using with home-manager (single-user / no multi-host, simpler)

```nix
{
  inputs.waktusolat.url = "github:NajibMalaysia/waktusolat-NajibMalaysia";

  # in your home-manager module list:
  imports = [ inputs.waktusolat.homeManagerModules.default ];

  services.waktusolat = {
    enable = true;
    zone = "SGR01";
    logLevel = "INFO";
  };
}
```

## xmobar

Add a `Run Com` to your `.xmobarrc`, polling once a second (interval is in
tenths of a second, so `10`):

```haskell
Run Com "waktusolat-render-xmobar" [] "waktusolat" 10
```

Then reference `%waktusolat%` in your `template`.

## Waybar (Niri)

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

## Ad-hoc lookup (no daemon needed)

```bash
waktusolat-cli SGR01
```

## Development

```bash
nix develop
bats tests/
shellcheck lib/*.sh bin/*
```
