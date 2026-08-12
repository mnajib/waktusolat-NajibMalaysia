#!/usr/bin/env bash
# lib/formatters/10-cli.sh
#
# Copyright (c) 2026 waktusolat-NajibMalaysia
# Licensed under the BSD 3-Clause License. See LICENSE file for details.

set -euo pipefail

TMP_OUT="${STATE_DIR}/reminder.tmp.cli"
FINAL_OUT="${STATE_DIR}/reminder.cli"

OLD_CLI=""
[[ "${IS_STALE}" == "true" ]] && OLD_CLI="[OLD DATA] "

cat <<EOF > "$TMP_OUT"
----------------------------------------
 Waktu Solat : ${ZONE} (${DAY}, ${G_DATE_ISO} / ${HDATE}) ${OLD_CLI}
----------------------------------------
 Subuh      : ${FJR}
 Syuruk     : ${SYU}
 Zohor      : ${ZHR}
 Asar       : ${ASR}
 Maghrib    : ${MGH}
 Isyak      : ${ISY}
----------------------------------------
EOF

mv "$TMP_OUT" "$FINAL_OUT"
