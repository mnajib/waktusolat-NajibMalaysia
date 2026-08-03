#!/usr/bin/env bash
# lib/xmobar-colorize.sh
#
# PORTED from xmonad-config-NajibMalaysia bin/lib/helpers.sh.
# These functions all understand xmobar's `<fc=#RRGGBB,#RRGGBB>text</fc>`
# markup, so they live in an xmobar-specific file -- a Waybar renderer has
# no use for them (Waybar recolors via CSS `class`, not embedded markup).
#
# Kept verbatim: pure_toggle_colors, pure_is_near_time, pure_is_started,
# pure_process_prayer_entry.
# DROPPED (dead/unused in the actively-running formatWaktuSolatForXmobar
# path): pure_toggle_color (singular), impure_colorize_time,
# pure_extract_prayer_times (had a literal 'your-regex-here' placeholder --
# never finished), pure_highlight_prayer_time, pure_testdata,
# pure_sound_a_beep, pure_is_near, pure_is_within_range,
# impure_string_from_file.

[[ "${_XMOBAR_COLORIZE_SH_INCLUDED:-}" == "true" ]] && return
declare -r _XMOBAR_COLORIZE_SH_INCLUDED="true"

# input:  toggle fg1 bg1 fg2 bg2
# output: "fg1,bg1" if toggle==0 else "fg2,bg2"
pure_toggle_colors() {
    local toggle="$1"
    local fg1="$2" bg1="$3"
    local fg2="$4" bg2="$5"

    if [[ "$toggle" -eq 0 ]]; then
        echo "$fg1,$bg1"
    else
        echo "$fg2,$bg2"
    fi
}

# pure_is_near_time <target HH:MM> <current HH:MM> <proximity_minutes>
# echoes 0 (true) if |target - current| <= proximity, else 1 (false)
pure_is_near_time() {
    local target_time="$1"
    local current_time="$2"
    local proximity="$3"

    local target_minutes=$((10#${target_time%%:*} * 60 + 10#${target_time##*:}))
    local current_minutes=$((10#${current_time%%:*} * 60 + 10#${current_time##*:}))
    local diff=$((target_minutes - current_minutes))

    if [[ ${diff#-} -le "$proximity" ]]; then
        echo 0
    else
        echo 1
    fi
}

# pure_is_started <current HH:MM> <start HH:MM>
# echoes 0 (true) if current_time >= start_time, else 1 (false)
pure_is_started() {
    local current_time="$1"
    local start_time="$2"

    local current_minutes=$((10#${current_time%%:*} * 60 + 10#${current_time##*:}))
    local start_minutes=$((10#${start_time%%:*} * 60 + 10#${start_time##*:}))

    if [[ $current_minutes -ge $start_minutes ]]; then
        echo 0
    else
        echo 1
    fi
}

# pure_process_prayer_entry <xmobar-formatted line> <current HH:MM> [toggle 0|1]
#
# Scans the line for "<Abbrev></fc><fc=#fg,#bg> HH:MM" occurrences and
# recolors each one based on proximity of HH:MM to current_time:
#   <15 min away, not yet started : blinking red/aqua
#   <15 min away, already started : solid red (background)
#   <30 min away, not yet started : blinking amber/aqua
#   <30 min away, already started : solid amber
#   otherwise                     : neutral (black on aqua)
# Also strips the "Ims" (Imsak) entry entirely -- ported as-is; Imsak isn't
# meaningful to remind/blink for since it's before Subuh even starts.
pure_process_prayer_entry() {
    local line="$1"
    local updated_line="$line"
    local result_line="$line"
    local current_time="$2"
    local toggle="${3:-0}"

    local foreground background new_foreground new_background new_colors
    local prayer_name prayer_time
    local pattern='([A-Za-z]{3})</fc><fc=#([afA-F0-9]{6}),#([a-fA-F0-9]{6})> ([0-9]{2}:[0-9]{2})'
    local pattern2 pattern3

    while [[ $updated_line =~ $pattern ]]; do
        foreground="${BASH_REMATCH[2]}"
        background="${BASH_REMATCH[3]}"
        prayer_name="${BASH_REMATCH[1]}"
        prayer_time="${BASH_REMATCH[4]}"

        pattern2="${prayer_name}</fc><fc=#${foreground},#${background}> ${prayer_time}"
        updated_line="${updated_line/${pattern2}//}"

        if [[ $(pure_is_near_time "$prayer_time" "$current_time" 15) = 0 ]]; then
            if [[ $(pure_is_started "$current_time" "$prayer_time") = 0 ]]; then
                new_colors=$(pure_toggle_colors "$toggle" "ffffff" "ff3333" "ffffff" "ff3333")
            else
                new_colors=$(pure_toggle_colors "$toggle" "ffffff" "ff3333" "000000" "7fffd4")
            fi
        elif [[ $(pure_is_near_time "$prayer_time" "$current_time" 30) = 0 ]]; then
            if [[ $(pure_is_started "$current_time" "$prayer_time") = 0 ]]; then
                new_colors=$(pure_toggle_colors "$toggle" "000000" "ffbf00" "000000" "ffbf00")
            else
                new_colors=$(pure_toggle_colors "$toggle" "000000" "ffbf00" "000000" "7fffd4")
            fi
        else
            new_colors="000000,7fffd4"
        fi

        new_foreground="${new_colors%,*}"
        new_background="${new_colors#*,}"

        pattern3="${prayer_name}</fc><fc=#${new_foreground},#${new_background}> ${prayer_time}"
        result_line="${result_line/${pattern2}/${pattern3}}"
    done

    # Strip the Imsak entry from the final line (ported as-is from helpers.sh)
    local final_result_line
    final_result_line=$(echo "$result_line" | sed 's/<fc=#[a-fA-F0-9]\{6\},#[a-fA-F0-9]\{6\}>Ims<\/fc><fc=#[a-fA-F0-9]\{6\},#[a-fA-F0-9]\{6\}> [0-9]\{2\}:[0-9]\{2\} <\/fc> //')
    echo "$final_result_line"
}
