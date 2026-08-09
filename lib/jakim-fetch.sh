#!/usr/bin/env bash
# lib/jakim-fetch.sh
#
# Copyright (c) 2026 waktusolat-NajibMalaysia
# Licensed under the BSD 3-Clause License. See LICENSE file for details.

# Guard clause
[[ "${_JAKIM_FETCH_SH_INCLUDED:-}" == "true" ]] && return
declare -r _JAKIM_FETCH_SH_INCLUDED="true"

: "${USER:=$(id -un)}"

# --- File locations -----------------------------------------------------
RAW_FETCH_FILE="/tmp/${USER}-waktusolat-raw.json"
RAW_BACKUP_FILE="/tmp/${USER}-waktusolat-raw.json.bak"
NEUTRAL_DATA_FILE="/tmp/${USER}-waktusolat-data.json"
NEUTRAL_DATA_FILE_SECONDARY=""

# init_waktusolat_paths <zone> <data_dir> [secondary_data_dir]
# Overrides paths to be specific to <zone>, with the primary neutral output
# written under <data_dir>/<zone>.json, and optional secondary output written
# under <secondary_data_dir>/<zone>.json.
init_waktusolat_paths() {
    local zone="$1"
    local data_dir="$2"
    local secondary_data_dir="${3:-}"

    RAW_FETCH_FILE="/tmp/${USER}-waktusolat-raw-${zone}.json"
    RAW_BACKUP_FILE="/tmp/${USER}-waktusolat-raw-${zone}.json.bak"
    NEUTRAL_DATA_FILE="${data_dir}/${zone}.json"

    if [[ -n "$secondary_data_dir" ]]; then
        NEUTRAL_DATA_FILE_SECONDARY="${secondary_data_dir}/${zone}.json"
    else
        NEUTRAL_DATA_FILE_SECONDARY=""
    fi

    log_debug "init_waktusolat_paths: zone=${zone} data_dir=${data_dir} NEUTRAL_DATA_FILE=${NEUTRAL_DATA_FILE} SECONDARY=${NEUTRAL_DATA_FILE_SECONDARY}"
}

# --- Global state -------------------------------------------------------
NAMASOLAT=()
MASASOLAT=()
ZON=""
HDATE=""
MDATE=""
MDATETIME=""
DAY=""
ERROR=false

resetData() {
    log_debug "Start resetData()"
    NAMASOLAT=()
    MASASOLAT=()
    ZON=""
    HDATE=""
    MDATE=""
    DAY=""
    log_debug "End resetData()"
}

fetchDataZone() {
    local zone="$1"
    log_debug "Start fetchDataZone() for zone: $zone"

    local agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    local accept_hdr="Accept: application/json"
    local url="https://www.e-solat.gov.my/index.php?r=esolatApi/TakwimSolat&period=today&zone=${zone}"

    curl -s -k -H "$accept_hdr" -A "$agent" "$url" > "$RAW_FETCH_FILE"

    if grep -q "403 ERROR" "$RAW_FETCH_FILE"; then
        log_debug "ERROR: Still getting CloudFront 403 block"
        ERROR=true
    fi

    log_debug "End fetchDataZone()"
}

extractData() {
    log_debug "Start extractData()"

    local internal_data
    internal_data=$(jq -r '.prayerTime[0] | to_entries | .[] | "\(.key),\(.value)"' "$RAW_FETCH_FILE" 2>/dev/null || true)

    local meta_data
    meta_data=$(jq -r '"serverTime,\(.serverTime)\nzone,\(.zone)"' "$RAW_FETCH_FILE" 2>/dev/null || true)

    if [[ -z "$internal_data" ]]; then
        log_debug "ERROR: jq failed to parse JSON in $RAW_FETCH_FILE"
        ERROR=true
        return
    fi

    local BAKIFS="$IFS"
    IFS=","
    while read -r NAME VALUE; do
        case "${NAME}" in
            'serverTime') MDATETIME="$VALUE" ;;
            'zone')       ZON="$VALUE" ;;
            'hijri')      HDATE="$VALUE" ;;
            'date')       MDATE="$VALUE" ;;
            'day')        DAY="$VALUE" ;;
            'imsak')      NAMASOLAT+=("Imsak");   MASASOLAT+=("${VALUE%:*}") ;;
            'fajr')       NAMASOLAT+=("Subuh");   MASASOLAT+=("${VALUE%:*}") ;;
            'syuruk')     NAMASOLAT+=("Syuruk");  MASASOLAT+=("${VALUE%:*}") ;;
            'dhuhr')      NAMASOLAT+=("Zohor");   MASASOLAT+=("${VALUE%:*}") ;;
            'asr')        NAMASOLAT+=("Asar");    MASASOLAT+=("${VALUE%:*}") ;;
            'maghrib')    NAMASOLAT+=("Maghrib"); MASASOLAT+=("${VALUE%:*}") ;;
            'isha')       NAMASOLAT+=("Isyak");   MASASOLAT+=("${VALUE%:*}") ;;
        esac
    done <<< "$(echo -e "$meta_data\n$internal_data")"
    IFS="$BAKIFS"

    log_debug "End extractData()"
}

checkData() {
    log_debug "Start checkData()"

    local arrayLength=${#NAMASOLAT[@]}

    if (( arrayLength == 7 )); then
        log_debug "Array length as we needed : $arrayLength"
        if [ "${NAMASOLAT[0]}" != "Imsak" ] || [ "${NAMASOLAT[1]}" != "Subuh" ] || \
           [ "${NAMASOLAT[2]}" != "Syuruk" ] || [ "${NAMASOLAT[3]}" != "Zohor" ] || \
           [ "${NAMASOLAT[4]}" != "Asar" ] || [ "${NAMASOLAT[5]}" != "Maghrib" ] || \
           [ "${NAMASOLAT[6]}" != "Isyak" ]; then
            log_debug "ERROR #001: Nama waktu solat tak sama"
            ERROR=true
        else
            log_debug "No error detected."
            ERROR=false
        fi
    else
        log_debug "ERROR #002: Array length NOT as we expected : $arrayLength"
        ERROR=true
    fi

    log_debug "End checkData()"
}

doBackup() {
    log_debug "Start doBackup()"
    log_debug "Do backup fetch source file to ${RAW_BACKUP_FILE}"
    cat "$RAW_FETCH_FILE" > "$RAW_BACKUP_FILE"
    log_debug "End doBackup()"
}

getOldGoodFetchData() {
    log_debug "Start getOldGoodFetchData()"
    if [[ ! -s "$RAW_BACKUP_FILE" ]]; then
        log_debug "No backup file at ${RAW_BACKUP_FILE} yet -- nothing to fall back to"
        return 0
    fi
    log_debug "Get previous backup fetched source from file ${RAW_BACKUP_FILE}"
    cat "$RAW_BACKUP_FILE" > "$RAW_FETCH_FILE"
    log_debug "End getOldGoodFetchData()"
}

pure_build_prayers_json() {
    local json="[]"
    local i
    for i in "${!NAMASOLAT[@]}"; do
        json=$(jq -c --arg name "${NAMASOLAT[$i]}" --arg time "${MASASOLAT[$i]}" \
            '. + [{"name_bm":$name,"time":$time}]' <<< "$json")
    done
    echo "$json"
}

impure_write_neutral_json() {
    log_debug "Start impure_write_neutral_json()"

    local out_tmp="${NEUTRAL_DATA_FILE}.tmp.$$"
    local prayers_json
    prayers_json="$(pure_build_prayers_json)"

    local is_stale_json
    if $ERROR; then is_stale_json=true; else is_stale_json=false; fi

    jq -n \
        --arg zone "$ZON" \
        --arg hijri_date "$HDATE" \
        --arg gregorian_date "$MDATE" \
        --arg day "$DAY" \
        --arg server_time "$MDATETIME" \
        --argjson is_stale "$is_stale_json" \
        --argjson prayers "$prayers_json" \
        '{zone:$zone, hijri_date:$hijri_date, gregorian_date:$gregorian_date,
          day:$day, server_time:$server_time, is_stale:$is_stale, prayers:$prayers}' \
        > "$out_tmp"

    chmod 0644 "$out_tmp"

    if [[ -n "${NEUTRAL_DATA_FILE_SECONDARY:-}" ]]; then
        local sec_dir
        sec_dir="$(dirname "$NEUTRAL_DATA_FILE_SECONDARY")"
        mkdir -p "$sec_dir"
        local sec_tmp="${NEUTRAL_DATA_FILE_SECONDARY}.tmp.$$"
        cp "$out_tmp" "$sec_tmp"
        chmod 0644 "$sec_tmp"
        mv "$sec_tmp" "$NEUTRAL_DATA_FILE_SECONDARY"
        log_debug "Wrote secondary target ${NEUTRAL_DATA_FILE_SECONDARY}"
    fi

    mv "$out_tmp" "$NEUTRAL_DATA_FILE"

    log_debug "Wrote ${NEUTRAL_DATA_FILE}"
    log_debug "End impure_write_neutral_json()"
}
