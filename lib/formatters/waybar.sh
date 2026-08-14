#!/usr/bin/env bash
# lib/formatters/waybar.sh
#
# Copyright (c) 2026 waktusolat-NajibMalaysia
# Licensed under the BSD 3-Clause License. See LICENSE file for details.

set -euo pipefail

#source "${LIB_DIR}/prayer-proximity.sh"

#FINAL_OUT="${STATE_DIR}/reminder.json"
FINAL_OUT="${STATE_DIR}/reminder-waybar.pango.xml"
TMP_OUT="${FINAL_OUT}.tmp.$$"

# Evaluate proximity class using a more accurate name and strip any trailing newlines
STATUS_CLASS="${STATUS_CLASS:-neutral}"
STATUS_CLASS="${STATUS_CLASS//$'\n'/}"

# Clean up ZONE to avoid trailing newlines in alt or text fields
ZONE="${ZONE//$'\n'/}"

OLD_TXT="     "
if [[ "$IS_STALE" == "true" ]]; then
    OLD_TXT="<span foreground='#ffffff' background='#ff4d4d'> OLD </span> "
fi

# Fetch individual prayer colors using the shared library function (pure bash namerefs)
#get_prayer_colors "$FJR" "$NOW_HM" "$TOGGLE" FJR_FG FJR_BG
#get_prayer_colors "$SYU" "$NOW_HM" "$TOGGLE" SYU_FG SYU_BG
#get_prayer_colors "$ZHR" "$NOW_HM" "$TOGGLE" ZHR_FG ZHR_BG
#get_prayer_colors "$ASR" "$NOW_HM" "$TOGGLE" ASR_FG ASR_BG
#get_prayer_colors "$MGH" "$NOW_HM" "$TOGGLE" MGH_FG MGH_BG
#get_prayer_colors "$ISY" "$NOW_HM" "$TOGGLE" ISY_FG ISY_BG

# Text for display on Waybar
# Construct the text layout using Pango markup tags and pre-calculated FG/BG variables
RAW_TEXT="<span foreground='#888888'>Data ${SERVER_TIME};</span>${OLD_TXT}<span foreground='#ff66ff'>(${ZONE}</span> <span foreground='#00ffff'>(${G_MONTH_ABB}</span> <span foreground='#00ffff'>${G_DATE_ISO}</span> <span foreground='#00ffff'>${G_DAY_ABB}</span> <span foreground='#ffff00'>(${H_MONTH_NAME}</span> <span foreground='#ffff00'>${HDATE}</span> <span foreground='#ffff00'>${H_DAY_NAME}</span> <span foreground='#000000' background='#ffffff'>Fjr</span><span foreground='#${FJR_FG}' background='#${FJR_BG}'> ${FJR} </span> <span foreground='#000000' background='#ffffff'>Syu</span><span foreground='#${SYU_FG}' background='#${SYU_BG}'> ${SYU} </span> <span foreground='#000000' background='#ffffff'>Zhr</span><span foreground='#${ZHR_FG}' background='#${ZHR_BG}'> ${ZHR} </span> <span foreground='#000000' background='#ffffff'>Asr</span><span foreground='#${ASR_FG}' background='#${ASR_BG}'> ${ASR} </span><span foreground='#ffff00'>)</span> <span foreground='#ffff00'>(${H_NEXT_DAY_NAME}</span> <span foreground='#000000' background='#ffffff'>Mgh</span><span foreground='#${MGH_FG}' background='#${MGH_BG}'> ${MGH} </span> <span foreground='#000000' background='#ffffff'>Isy</span><span foreground='#${ISY_FG}' background='#${ISY_BG}'> ${ISY} </span><span foreground='#ffff00'>)</span><span foreground='#00ffff'>)</span><span foreground='#ff66ff'>)</span>"
#
#read -r -d '' RAW_TEXT <<EOF
#<span foreground='#888888'>Data ${SERVER_TIME};</span>${OLD_TXT}<span foreground='#ff66ff'>(${ZONE}</span> <span foreground='#00ffff'>(${G_MONTH_ABB}</span> <span foreground='#00ffff'>${G_DATE_ISO}</span> <span foreground='#00ffff'>${G_DAY_ABB}</span> <span foreground='#ffff00'>(${H_MONTH_NAME}</span> <span foreground='#ffff00'>${HDATE}</span> <span foreground='#ffff00'>${H_DAY_NAME}</span> <span foreground='#000000' background='#ffffff'>Fjr</span><span foreground='#${FJR_FG}' background='#${FJR_BG}'> ${FJR} </span> <span foreground='#000000' background='#ffffff'>Syu</span><span foreground='#${SYU_FG}' background='#${SYU_BG}'> ${SYU} </span> <span foreground='#000000' background='#ffffff'>Zhr</span><span foreground='#${ZHR_FG}' background='#${ZHR_BG}'> ${ZHR} </span> <span foreground='#000000' background='#ffffff'>Asr</span><span foreground='#${ASR_FG}' background='#${ASR_BG}'> ${ASR} </span><span foreground='#ffff00'>)</span> <span foreground='#ffff00'>(${H_NEXT_DAY_NAME}</span> <span foreground='#000000' background='#ffffff'>Mgh</span><span foreground='#${MGH_FG}' background='#${MGH_BG}'> ${MGH} </span> <span foreground='#000000' background='#ffffff'>Isy</span><span foreground='#${ISY_FG}' background='#${ISY_BG}'> ${ISY} </span><span foreground='#ffff00'>)</span><span foreground='#00ffff'>)</span><span foreground='#ff66ff'>)</span>
#EOF
#
#RAW_TEXT="<span foreground='#888888'>Data ${SERVER_TIME};</span>${OLD_TXT}\
#  <span foreground='#ff66ff'>(${ZONE}</span> \
#  <span foreground='#00ffff'>(${G_MONTH_ABB}</span> <span foreground='#00ffff'>${G_DATE_ISO}</span> <span foreground='#00ffff'>${G_DAY_ABB}</span> \
#  <span foreground='#ffff00'>(${H_MONTH_NAME}</span> <span foreground='#ffff00'>${HDATE}</span> <span foreground='#ffff00'>${H_DAY_NAME}</span> \
#  <span foreground='#000000' background='#ffffff'>Fjr</span><span foreground='#${FJR_FG}' background='#${FJR_BG}'> ${FJR} </span> \
#  <span foreground='#000000' background='#ffffff'>Syu</span><span foreground='#${SYU_FG}' background='#${SYU_BG}'> ${SYU} </span> \
#  <span foreground='#000000' background='#ffffff'>Zhr</span><span foreground='#${ZHR_FG}' background='#${ZHR_BG}'> ${ZHR} </span> \
#  <span foreground='#000000' background='#ffffff'>Asr</span><span foreground='#${ASR_FG}' background='#${ASR_BG}'> ${ASR} </span><span foreground='#ffff00'>)</span> \
#  <span foreground='#ffff00'>(${H_NEXT_DAY_NAME}</span> \
#  <span foreground='#000000' background='#ffffff'>Mgh</span><span foreground='#${MGH_FG}' background='#${MGH_BG}'> ${MGH} </span> \
#  <span foreground='#000000' background='#ffffff'>Isy</span><span foreground='#${ISY_FG}' background='#${ISY_BG}'> ${ISY} </span><span foreground='#ffff00'>)</span>\
#  <span foreground='#00ffff'>)</span><span foreground='#ff66ff'>)</span>"

# Text for tooltip of the Waybar
TOOLTIP_DISPLAY="Zone: ${ZONE}\nDate: ${G_DATE_ISO} (${G_DAY_ABB})\nHijri: ${HDATE} ${H_MONTH_NAME}\nServer Time: ${SERVER_TIME}\nSubuh: ${FJR} | Syuruk: ${SYU} | Zohor: ${ZHR} | Asar: ${ASR} | Maghrib: ${MGH} | Isyak: ${ISY}"
#
#TOOLTIP_DISPLAY="Zone: ${ZONE}\n" \
#"Date: ${G_DATE_ISO} (${G_DAY_ABB})\n" \
#"Hijri: ${HDATE} ${H_MONTH_NAME}\n" \
#"Server Time: ${SERVER_TIME}\n\n" \
#"Subuh: ${FJR} | Syuruk: ${SYU} | Zohor: ${ZHR} | Asar: ${ASR} | Maghrib: ${MGH} | Isyak: ${ISY}"
#
#read -r -d '' TOOLTIP_DISPLAY <<EOF
#Zone: ${ZONE}
#Date: ${G_DATE_ISO} (${G_DAY_ABB})
#Hijri: ${HDATE} ${H_MONTH_NAME}
#Server Time: ${SERVER_TIME}
#
#Subuh: ${FJR}
#Syuruk: ${SYU}
#Zohor: ${ZHR}
#Asar: ${ASR}
#Maghrib: ${MGH}
#Isyak: ${ISY}
#EOF

# Escape strings safely using jq for JSON payload, stripping trailing newlines from echo/jq output if any
SAFE_TEXT=$(echo -n "$RAW_TEXT" | jq -aRs .)
SAFE_ALT=$(echo -n "$ZONE" | jq -aRs .)
SAFE_TOOLTIP=$(echo -n "$TOOLTIP_DISPLAY" | jq -aRs .)
SAFE_CLASS=$(echo -n "$STATUS_CLASS" | jq -aRs .)

# Write entirely to the isolated temp file first (atomic write)[cite: 2, 7]
printf '{"text": %s, "alt": %s, "tooltip": %s, "class": [%s]}\n' \
    "$SAFE_TEXT" "$SAFE_ALT" "$SAFE_TOOLTIP" "$SAFE_CLASS" > "$TMP_OUT"

# Instantly swap the temp file into place atomically[cite: 2, 7]
mv -f "$TMP_OUT" "$FINAL_OUT"
