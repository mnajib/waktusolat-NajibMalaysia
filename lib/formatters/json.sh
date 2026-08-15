#!/usr/bin/env bash
# lib/formatters/json.sh
#
# Copyright (c) 2026 waktusolat-NajibMalaysia
# Licensed under the BSD 3-Clause License. See LICENSE file for details.

set -euo pipefail

# Ensure proximity functions are loaded
source "${LIB_DIR}/prayer-proximity.sh"

TMP_OUT="${STATE_DIR}/reminder.tmp.json"
FINAL_OUT="${STATE_DIR}/reminder.json"

# Clean up variables to prevent trailing newlines
ZONE="${ZONE//$'\n'/}"
SERVER_TIME="${SERVER_TIME//$'\n'/}"
G_DATE_ISO="${G_DATE_ISO//$'\n'/}"
G_MONTH_ABB="${G_MONTH_ABB//$'\n'/}"
G_DAY_ABB="${G_DAY_ABB//$'\n'/}"
HDATE="${HDATE//$'\n'/}"
H_MONTH_NAME="${H_MONTH_NAME//$'\n'/}"
H_DAY_NAME="${H_DAY_NAME//$'\n'/}"
H_NEXT_DAY_NAME="${H_NEXT_DAY_NAME//$'\n'/}"
STATUS_CLASS="${STATUS_CLASS:-neutral}"
STATUS_CLASS="${STATUS_CLASS//$'\n'/}"
IS_STALE="${IS_STALE:-false}"

# Helper function to compute delta minutes and return stage
get_prayer_stage() {
    local prayer_hm="$1"    # Accepts the target prayer time formatted as HH:MM
    if [[ -z "$prayer_hm" || "$prayer_hm" == "-" ]]; then  # Checks if the input is empty (-z) or set to a placeholder hyper-dash ("-")
        echo "neutral"
        return
    fi

    local p_h=${prayer_hm%%:*} p_m=${prayer_hm##*:}    # from the prayer_hm; get the prayer hour time and set it to p_h, get the prayer minute time and set it to p_m
    local n_h=${NOW_HM%%:*} n_m=${NOW_HM##*:}          # from the current (now) time; get the hour time and set it to n_h, get minute time and set it to n_m

    local prayer_min=$(( 10#$p_h * 60 + 10#$p_m ))
    local now_min=$(( 10#$n_h * 60 + 10#$n_m ))
    local delta=$(( prayer_min - now_min ))

    classify_prayer_proximity "$delta"
}

#get_prayer_colors_fix "$FJR" "$NOW_HM" "$TOGGLE" FJR_FG FJR_BG
#get_prayer_colors_fix "$SYU" "$NOW_HM" "$TOGGLE" SYU_FG SYU_BG
#get_prayer_colors_fix "$ZHR" "$NOW_HM" "$TOGGLE" ZHR_FG ZHR_BG
#get_prayer_colors_fix "$ASR" "$NOW_HM" "$TOGGLE" ASR_FG ASR_BG
#get_prayer_colors_fix "$MGH" "$NOW_HM" "$TOGGLE" MGH_FG MGH_BG
#get_prayer_colors_fix "$ISY" "$NOW_HM" "$TOGGLE" ISY_FG ISY_BG
#
FJR_FG="000000"
FJR_BG="7fffd4"
SYU_FG="000000"
SYU_BG="7fffd4"
ZHR_FG="000000"
ZHR_BG="7fffd4"
ASR_FG="000000"
ASR_BG="7fffd4"
MGH_FG="000000"
MGH_BG="7fffd4"
ISY_FG="000000" # black
ISY_BG="7fffd4" # aquamarine

# Evaluate proximity stages
FJR_STAGE=$(get_prayer_stage "$FJR")
SYU_STAGE=$(get_prayer_stage "$SYU")
ZHR_STAGE=$(get_prayer_stage "$ZHR")
ASR_STAGE=$(get_prayer_stage "$ASR")
MGH_STAGE=$(get_prayer_stage "$MGH")
ISY_STAGE=$(get_prayer_stage "$ISY")

# Export to process environment for jq $ENV access
export ZONE SERVER_TIME IS_STALE G_DATE_ISO G_MONTH_ABB G_DAY_ABB HDATE H_MONTH_NAME H_DAY_NAME H_NEXT_DAY_NAME STATUS_CLASS
export FJR FJR_STAGE FJR_FG FJR_BG
export SYU SYU_STAGE SYU_FG SYU_BG
export ZHR ZHR_STAGE ZHR_FG ZHR_BG
export ASR ASR_STAGE ASR_FG ASR_BG
export MGH MGH_STAGE MGH_FG MGH_BG
export ISY ISY_STAGE ISY_FG ISY_BG

jq -n '{
  zone: $ENV.ZONE,
  server_time: $ENV.SERVER_TIME,
  is_stale: ($ENV.IS_STALE == "true"),
  gregorian: {
    date: $ENV.G_DATE_ISO,
    month_abb: $ENV.G_MONTH_ABB,
    day_abb: $ENV.G_DAY_ABB
  },
  hijri: {
    date: $ENV.HDATE,
    month_name: $ENV.H_MONTH_NAME,
    day_name: $ENV.H_DAY_NAME,
    next_day_name: $ENV.H_NEXT_DAY_NAME
  },
  status_class: $ENV.STATUS_CLASS,
  prayers: {
    fajr: {
      name: "Fjr",
      time: $ENV.FJR,
      stage: $ENV.FJR_STAGE,
      fg: $ENV.FJR_FG,
      bg: $ENV.FJR_BG
    },
    syuruk: {
      name: "Syu",
      time: $ENV.SYU,
      stage: $ENV.SYU_STAGE,
      fg: $ENV.SYU_FG,
      bg: $ENV.SYU_BG
    },
    zohor: {
      name: "Zhr",
      time: $ENV.ZHR,
      stage: $ENV.ZHR_STAGE,
      fg: $ENV.ZHR_FG,
      bg: $ENV.ZHR_BG
    },
    asr: {
      name: "Asr",
      time: $ENV.ASR,
      stage: $ENV.ASR_STAGE,
      fg: $ENV.ASR_FG,
      bg: $ENV.ASR_BG
    },
    maghrib: {
      name: "Mgh",
      time: $ENV.MGH,
      stage: $ENV.MGH_STAGE,
      fg: $ENV.MGH_FG,
      bg: $ENV.MGH_BG
    },
    isha: {
      name: "Isy",
      time: $ENV.ISY,
      stage: $ENV.ISY_STAGE,
      fg: $ENV.ISY_FG,
      bg: $ENV.ISY_BG
    }
  }
}' > "$TMP_OUT"

mv -f "$TMP_OUT" "$FINAL_OUT"
