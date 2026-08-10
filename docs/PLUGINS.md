# Formatter Plugins & Extensions

`waktusolat-reminder` uses a **modular plugin architecture** to render prayer data across various desktop bars, terminals, and web widgets.

Instead of hardcoding presentation formats inside the main loop, `waktusolat-reminder` calculates state once and delegates formatting to standalone executable scripts located in plugin directories.


## How It Works

During every 1-second update cycle, `waktusolat-reminder`:
1. Parses prayer data from local cache (`/var/cache/waktusolat/<ZONE>.json` or `/var/lib/waktusolat/<ZONE>.json`).
2. Calculates active prayer highlighting, date conversions (Gregorian and Hijri), and stale state badges.
3. Exports calculated properties into standard environment variables.
4. Executes all executable `.sh` files in the built-in formatter directory and user custom directory.

```
               ┌───────────────────────────────┐
               │    waktusolat-reminder        │
               │ (Data Parsing & State Engine) │
               └───────────────┬───────────────┘
                               │
                 Exports State Environment
                               │
     ┌─────────────────────────┼─────────────────────────┐
     ▼                         ▼                         ▼
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│ lib/formatters/  │      │ lib/formatters/  │      │ ~/.config/.../   │
│   00-json.sh     │      │   20-xmobar.sh   │      │   99-custom.sh   │
└────────┬─────────┘      └────────┬─────────┘      └────────┬─────────┘
         │                         │                         │
         ▼                         ▼                         ▼
    reminder.json             reminder.txt              reminder.custom
```


## Directory Locations

Plugins are loaded sequentially from two locations:

1. **Built-in System Plugins:**
   Located in `lib/formatters/` (or via `WAKTUSOLAT_FORMATTER_DIR`).
2. **User Custom Plugins:**
   Located in `${XDG_CONFIG_HOME:-$HOME/.config}/waktusolat/formatters/`.


## Built-in Formatter Plugins

| Plugin | File Name | Target Output File | Purpose |
|--------|-----------|--------------------+---------|
| JSON | `00-json.sh` | `${STATE_DIR}/reminder.json` | Neutral structured state for external integrations. |
| CLI | `10-cli.sh` | `${STATE_DIR}/reminder.cli` | Terminal formatted table block. |
| XMobar | `20-xmobar.sh` | `${STATE_DIR}/reminder.txt` | Colored status output using XMobar `<fc>` markup. |
| Waybar | `30-waybar.sh` | `${STATE_DIR}/reminder.html` | Markup output for Waybar / Pango `<span color=...>` elements. |


## Exported Context Environment Variables

Custom plugin scripts inherit the following environment variables during execution:

### Prayer Schedule Times
* `FJR` — Subuh time (e.g. `05:58`)
* `SYU` — Syuruk time (e.g. `07:14`)
* `ZHR` — Zohor time (e.g. `13:22`)
* `ASR` — Asar time (e.g. `16:41`)
* `MGH` — Maghrib time (e.g. `19:28`)
* `ISY` — Isyak time (e.g. `20:39`)

### Active Prayer Highlight Colors
* `COLOR_FJR`, `COLOR_SYU`, `COLOR_ZHR`, `COLOR_ASR`, `COLOR_MGH`, `COLOR_ISY` — Hex color codes (`#ffbf00` when active, `#7fffd4` default).

### Metadata & Dates
* `ZONE` — Selected JAKIM zone code (e.g. `SGR01`)
* `SERVER_TIME` — Timestamp of raw data
* `IS_STALE` — `true` if serving fallback cache, `false` otherwise
* `DAY` — Day of week in Bahasa Malaysia
* `G_DATE_ISO`, `G_MONTH_ABB`, `G_DAY_ABB` — Gregorian ISO date and abbreviations
* `HDATE`, `H_MONTH_NAME`, `H_DAY_NAME`, `H_NEXT_DAY_NAME` — Hijri date details
* `STATE_DIR` — Output directory path (`/run/waktusolat` or `/run/user/<UID>/waktusolat`)


## Creating a Custom Plugin

To add a new format (e.g. Polybar, Rofi, or custom Desktop Notification):

1. Create a script in `~/.config/waktusolat/formatters/99-my-widget.sh`:

```bash
#!/usr/bin/env bash
# ~/.config/waktusolat/formatters/99-my-widget.sh

set -euo pipefail

TMP_OUT="${STATE_DIR}/reminder.tmp.widget"
FINAL_OUT="${STATE_DIR}/reminder.widget"

cat <<EOF> "$TMP_OUT"
Solat Zone: ${ZONE}
Subuh: ${FJR} | Zohor: ${ZHR} \vert{} Asar:${ASR} | Maghrib: ${MGH} \vert{} Isyak:${ISY}
EOF

# Atomically write to prevent UI flickering
mv "$TMP_OUT" "$FINAL_OUT"
```

2. Make the script executable:

```Bash
chmod +x ~/.config/waktusolat/formatters/99-my-widget.sh
```

The script will be automatically invoked by `waktusolat-reminder` on the next 1-second iteration cycle.


