#!/usr/bin/env bash
# lib/prayer-proximity.sh
#
# NEW. Implements the confirmed spec:
#   30-0 min BEFORE a prayer -> blinking (amber for 15-30 min out, red for
#                                0-15 min out)
#   0-30 min AFTER a prayer  -> solid    (red for 0-15 min elapsed, amber
#                                for 15-30 min elapsed)
#   otherwise                -> neutral
#
# Color scheme matches the OLD xmobar implementation exactly:
#   neutral       fg=000000 bg=7fffd4
#   amber (solid) fg=000000 bg=ffbf00
#   red   (solid) fg=ffffff bg=ff3333
#   blink = alternate every second between the colored state and neutral

[[ "${_PRAYER_PROXIMITY_SH_INCLUDED:-}" == "true" ]] && return
declare -r _PRAYER_PROXIMITY_SH_INCLUDED="true"

# hm_to_minutes "HH:MM" -> integer minutes since midnight
hm_to_minutes() {
    local hm="$1"
    echo $(( 10#${hm%%:*} * 60 + 10#${hm##*:} ))
}

# classify_prayer_proximity <delta_minutes>
# delta = prayer_time_minutes - now_minutes
#   delta > 0  => prayer still in the future ("before")
#   delta <= 0 => prayer has arrived or passed ("at/after")
classify_prayer_proximity() {
    local delta="$1"
    if   (( delta > 30 ));   then echo "neutral"
    elif (( delta > 15 ));   then echo "blink_amber"    # 15 < delta <= 30 (before)
    elif (( delta > 0  ));   then echo "blink_red"       # 0  < delta <= 15 (before)
    elif (( delta >= -15 )); then echo "solid_red"       # -15 <= delta <= 0 (at/after)
    elif (( delta >= -30 )); then echo "solid_amber"     # -30 <= delta < -15 (after)
    else echo "neutral"
    fi
}

# prayer_proximity_colors <prayer_time "HH:MM"> <now_time "HH:MM"> <toggle 0|1>
# Echoes "FG,BG" (hex, no '#') for direct use in an <fc=#FG,#BG> tag.
prayer_proximity_colors() {
    local prayer_hm="$1"
    local now_hm="$2"
    local toggle="$3"

    if [[ -z "$prayer_hm" || "$prayer_hm" == "-" ]]; then
        echo "000000,7fffd4"
        return
    fi

    local prayer_min now_min delta class
    prayer_min=$(hm_to_minutes "$prayer_hm")
    now_min=$(hm_to_minutes "$now_hm")
    delta=$(( prayer_min - now_min ))
    class=$(classify_prayer_proximity "$delta")

    case "$class" in
        neutral)      echo "000000,7fffd4" ;;
        solid_amber)  echo "000000,ffbf00" ;;
        solid_red)    echo "ffffff,ff3333" ;;
        blink_amber)  [[ "$toggle" == "0" ]] && echo "000000,ffbf00" || echo "000000,7fffd4" ;;
        blink_red)    [[ "$toggle" == "0" ]] && echo "ffffff,ff3333" || echo "000000,7fffd4" ;;
    esac
}

# NEW: 100% Pure bash. Zero subshells/forks. Uses namerefs for instant returns.
# get_prayer_colors <prayer_hm> <now_hm> <toggle> <out_fg_var> <out_bg_var>
get_prayer_colors() {
    local prayer_hm="$1" now_hm="$2" toggle="$3"
    local -n _fg="$4" _bg="$5" # Nameref: assigns directly to the parent variables

    if [[ -z "$prayer_hm" || "$prayer_hm" == "-" ]]; then
        _fg="000000"; _bg="7fffd4"
        return
    fi

    # Native string splitting (avoids hm_to_minutes subshell entirely)
    # 10# forces base-10 to prevent octal errors on numbers like "08"
    local p_h=${prayer_hm%%:*} p_m=${prayer_hm##*:}
    local n_h=${now_hm%%:*} n_m=${now_hm##*:}

    local prayer_min=$(( 10#$p_h * 60 + 10#$p_m ))
    local now_min=$(( 10#$n_h * 60 + 10#$n_m ))
    local delta=$(( prayer_min - now_min ))

    local class="neutral"
    if   (( delta > 30 ));   then class="neutral"
    elif (( delta > 15 ));   then class="blink_amber"
    elif (( delta > 0  ));   then class="blink_red"
    elif (( delta >= -15 )); then class="solid_red"
    elif (( delta >= -30 )); then class="solid_amber"
    fi

    case "$class" in
        neutral)      _fg="000000"; _bg="7fffd4" ;;
        solid_amber)  _fg="000000"; _bg="ffbf00" ;;
        solid_red)    _fg="ffffff"; _bg="ff3333" ;;
        blink_amber)  [[ "$toggle" == "0" ]] && { _fg="000000"; _bg="ffbf00"; } || { _fg="000000"; _bg="7fffd4"; } ;;
        blink_red)    [[ "$toggle" == "0" ]] && { _fg="ffffff"; _bg="ff3333"; } || { _fg="000000"; _bg="7fffd4"; } ;;
    esac
}
