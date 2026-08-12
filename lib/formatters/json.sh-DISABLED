#!/usr/bin/env bash
# lib/formatters/00-json.sh
#
# Copyright (c) 2026 waktusolat-NajibMalaysia
# Licensed under the BSD 3-Clause License. See LICENSE file for details.

set -euo pipefail

TMP_OUT="${STATE_DIR}/reminder.tmp.json"
FINAL_OUT="${STATE_DIR}/reminder.json"

jq -n \
  --arg zone "${ZONE}" \
  --arg stime "${SERVER_TIME}" \
  --argjson is_stale "${IS_STALE}" \
  --arg day "${DAY}" \
  --arg fjr "${FJR}" \
  --arg syu "${SYU}" \
  --arg zhr "${ZHR}" \
  --arg asr "${ASR}" \
  --arg mgh "${MGH}" \
  --arg isy "${ISY}" \
  --arg toggle "${TOGGLE}" \
  '{
    zone: $zone,
    server_time: $stime,
    is_stale: $is_stale,
    day: $day,
    subuh: $fjr,
    syuruk: $syu,
    zohor: $zhr,
    asar: $asr,
    maghrib: $mgh,
    isyak: $isy,
    toggle: $toggle
  }' > "$TMP_OUT"

mv "$TMP_OUT" "$FINAL_OUT"
