# waktusolat-NajibMalaysia

JAKIM prayer-time fetcher + status-bar renderers, as a standalone Nix flake.

Split out of `xmonad-config-NajibMalaysia` so that xmonad and Niri (or any
other WM) can share **one** fetcher process instead of each running its own
copy against the JAKIM API.

## Architecture

```
                         systemd --user
                  ┌───────────────────────────┐
                  │  waktusolat-fetchd.service │  <- ONE instance, WM-agnostic
                  └─────────────┬──────────────┘
                                │ writes
                                ▼
                 /tmp/$USER-waktusolat-data.json   (neutral JSON, no markup)
                     ▲                        ▲
                     │ reads                  │ reads
        ┌────────────┴───────────┐  ┌─────────┴────────────────┐
        │ waktusolat-render-     │  │ waktusolat-render-        │
        │ xmobar                 │  │ waybar                    │
        └────────────┬────────────┘  └─────────┬──────────────┘
                     ▼                          ▼
                 xmobar                    Waybar (Niri)
```

`waktusolat-fetchd` is guarded by `flock` (`/tmp/$USER-waktusolat-fetchd.lock`)
as a belt-and-braces safety net, but the real fix is that it's started once
by `systemd --user`, `WantedBy=graphical-session.target` -- neither xmonad
nor Niri need to spawn or kill it.

## Using with home-manager

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
