#!/usr/bin/env bash
# lib/formatters/30-waybar.sh
#
# Copyright (c) 2026 waktusolat-NajibMalaysia
# Licensed under the BSD 3-Clause License. See LICENSE file for details.

set -euo pipefail

TMP_OUT="${STATE_DIR}/reminder.tmp.html"
FINAL_OUT="${STATE_DIR}/reminder.html"

OLD_HTML="     "
if [[ "${IS_STALE}" == "true" ]]; then
    OLD_HTML="<span background='#ff4d4d' color='#ffffff'> OLD </span> "
fi

cat <<EOF > "$TMP_OUT"
${OLD_HTML}<span color='#ff66ff'>${ZONE}</span> <span background='#ffffff' color='#000000'>Fjr</span> ${FJR} <span background='#ffffff' color='#000000'>Syu</span> ${SYU} <span background='#ffffff' color='#000000'>Zhr</span> ${ZHR} <span background='#ffffff' color='#000000'>Asr</span> ${ASR} <span background='#ffffff' color='#000000'>Mgh</span> ${MGH} <span background='#ffffff' color='#000000'>Isy</span> ${ISY}
EOF

mv "$TMP_OUT" "$FINAL_OUT"
