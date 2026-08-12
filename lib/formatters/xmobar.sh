#!/usr/bin/env bash
# lib/formatters/xmobar.sh
# Copyright (c) 2026 waktusolat-NajibMalaysia
# Licensed under the BSD 3-Clause License. See LICENSE file for details.

set -euo pipefail

#source "${LIB_DIR}/prayer-proximity.sh"

FINAL_OUT="${STATE_DIR}/reminder.txt"
#FINAL_OUT="${STATE_DIR}/reminder-xmobar.txt"
# Create a unique temp file in the same directory (ensures mv is atomic on the same mount)
TMP_OUT="${FINAL_OUT}.tmp.$$"

OLD_TXT="     "
if [[ "$IS_STALE" == "true" ]]; then
    OLD_TXT="<fc=#ffffff,#ff4d4d> OLD </fc> "
fi

#get_prayer_colors "$FJR" "$NOW_HM" "$TOGGLE" FJR_FG FJR_BG
#get_prayer_colors "$SYU" "$NOW_HM" "$TOGGLE" SYU_FG SYU_BG
#get_prayer_colors "$ZHR" "$NOW_HM" "$TOGGLE" ZHR_FG ZHR_BG
#get_prayer_colors "$ASR" "$NOW_HM" "$TOGGLE" ASR_FG ASR_BG
#get_prayer_colors "$MGH" "$NOW_HM" "$TOGGLE" MGH_FG MGH_BG
#get_prayer_colors "$ISY" "$NOW_HM" "$TOGGLE" ISY_FG ISY_BG

# Write entirely to the isolated temp file first, using pre-calculated prayer colors
cat <<EOF > "$TMP_OUT"
<fc=#888888>Data ${SERVER_TIME};</fc>${OLD_TXT}<fc=#ff66ff>(${ZONE}</fc> <fc=#00ffff>(${G_MONTH_ABB}</fc> <fc=#00ffff>${G_DATE_ISO}</fc> <fc=#00ffff>${G_DAY_ABB}</fc> <fc=#ffff00>(${H_MONTH_NAME}</fc> <fc=#ffff00>${HDATE}</fc> <fc=#ffff00>${H_DAY_NAME}</fc> <fc=#000000,#ffffff>Fjr</fc><fc=#${FJR_FG},#${FJR_BG}> ${FJR} </fc> <fc=#000000,#ffffff>Syu</fc><fc=#${SYU_FG},#${SYU_BG}> ${SYU} </fc> <fc=#000000,#ffffff>Zhr</fc><fc=#${ZHR_FG},#${ZHR_BG}> ${ZHR} </fc> <fc=#000000,#ffffff>Asr</fc><fc=#${ASR_FG},#${ASR_BG}> ${ASR} </fc><fc=#ffff00>)</fc> <fc=#ffff00>(${H_NEXT_DAY_NAME}</fc> <fc=#000000,#ffffff>Mgh</fc><fc=#${MGH_FG},#${MGH_BG}> ${MGH} </fc> <fc=#000000,#ffffff>Isy</fc><fc=#${ISY_FG},#${ISY_BG}> ${ISY} </fc><fc=#ffff00>)</fc><fc=#00ffff>)</fc><fc=#ff66ff>)</fc>
EOF

# Instantly swap the temp file into place atomically
mv -f "$TMP_OUT" "$FINAL_OUT"
