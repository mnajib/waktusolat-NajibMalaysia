# Status Bar Integrations

Because the system-level state daemon continuously updates files in RAM disk (`/run/waktusolat/`), status bar configurations can simply read these files directly with virtually zero CPU overhead.

## xmobar Integration

Use a CommandReader or PipeReader to display formatted text:

`~/.config/xmobar/xmobar.hs`:

```haskell
Config {
    -- ...
    commands = [
        --Run Com "waktusolat-render-xmobar" [] "waktusolat" 10

        -- Reads the pre-formatted xmobar string from tmpfs every second
        Run CommandReader "cat /run/waktusolat/reminder.txt" "waktusolat"
    ],
    --template = "%UnsafeXMonadLog% }{ %waktusolat% | %date%"
    template = " %Unset% | %waktusolat% | %date% "
}

```

## Waybar Integration (Niri / Hyprland)

Use a custom module running in continuous script execution mode.

`~/.config/waybar/config.jsonc`:

```jsonc
"custom/waktusolat": {
    //"exec": "waktusolat-render-waybar",
    //"exec": "cat /run/waktusolat/reminder.html",
    "exec": "cat /run/waktusolat/reminder.json",
    "return-type": "json",
    "interval": 1, // 30, // 1 seconds for blinking effect
    "tooltip": true
}
```

Or, if using the pre-formatted plain Pango markup output:

```Pango
  "custom/waktusolat": {
    //"exec": "cat /run/waktusolat/reminder.txt",
    "exec": "cat /run/waktusolat/reminder.html",
    "interval": 1
  }
```

## Generic / Polybar / dwmbar Configuration

For simple bar scripts or Polybar `custom/script` modules:

```
[module/waktusolat]
  type = custom/script
  exec = cat /run/waktusolat/reminder.cli
  interval = 1
  tail = false
```

## Ad-hoc lookup (no daemon needed)

Query formatted prayer times directly in your terminal without invoking a status bar renderer:

```bash
waktusolat-cli SGR01
```

