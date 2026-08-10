#!/usr/bin/env bash
# lib/formatters/xmobar.sh
# Copyright (c) 2026 waktusolat-NajibMalaysia
# Licensed under the BSD 3-Clause License. See LICENSE file for details.

set -euo pipefail

TMP_OUT="${STATE_DIR}/reminder.tmp.txt"
FINAL_OUT="${STATE_DIR}/reminder.txt"

OLD_TXT="     "
if [[ "$IS_STALE" == "true" ]]; then
    OLD_TXT="<fc=#ffffff,#ff4d4d> OLD </fc> "
fi

cat <<EOF > "$TMP_OUT"
<fc=#888888>Data ${SERVER_TIME};</fc> ${OLD_TXT}<fc=#ff66ff>(${ZONE}</fc> <fc=#00ffff>(${G_MONTH_ABB}</fc> <fc=#00ffff>${G_DATE_ISO}</fc> <fc=#00ffff>${G_DAY_ABB}</fc> <fc=#ffff00>(${H_MONTH_NAME}</fc> <fc=#ffff00>${HDATE}</fc> <fc=#ffff00>${H_DAY_NAME}</fc> <fc=#000000,#ffffff>Fjr</fc><fc=#000000,${COLOR_FJR}> ${FJR} </fc> <fc=#000000,#ffffff>Syu</fc><fc=#000000,${COLOR_SYU}> ${SYU} </fc> <fc=#000000,#ffffff>Zhr</fc><fc=#000000,${COLOR_ZHR}> ${ZHR} </fc> <fc=#000000,#ffffff>Asr</fc><fc=#000000,${COLOR_ASR}> ${ASR} </fc><fc=#ffff00>)</fc> <fc=#ffff00>(${H_NEXT_DAY_NAME}</fc> <fc=#000000,#ffffff>Mgh</fc><fc=#000000,${COLOR_MGH}> ${MGH} </fc> <fc=#000000,#ffffff>Isy</fc><fc=#000000,${COLOR_ISY}> ${ISY} </fc><fc=#ffff00>)</fc><fc=#00ffff>)</fc><fc=#ff66ff>)</fc>
EOF

mv "$TMP_OUT" "$FINAL_OUT"
