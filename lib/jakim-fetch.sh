#!/usr/bin/env bash
# lib/jakim-fetch.sh
#
# PORTED from xmonad-config-NajibMalaysia bin/lib/waktusolatlib.sh.
# Kept: resetData, fetchDataZone, extractData, checkData, doBackup,
#       getOldGoodFetchData -- these are the "talk to JAKIM and validate"
#       responsibilities, unchanged in behaviour.
# REMOVED: everything display/formatting related (namaBulanH, namaBulanM,
#       nomHari, namaHariBM, all printWaktuSolatFor*, formatWaktuSolatForXmobar*,
#       and every dead/commented alternate-formatter function). Those belong
#       to renderers (bin/waktusolat-render-*), not the fetcher -- the fetcher
#       must not know xmobar's <fc=...> syntax exists.
# ADDED: pure_build_prayers_json, impure_write_neutral_json -- these replace
#       ONELINE/pushStringToFile with a single canonical JSON file that any
#       renderer (xmobar, waybar, ironbar, eww, ...) can read independently.

# Guard clause
[[ "${_JAKIM_FETCH_SH_INCLUDED:-}" == "true" ]] && return
declare -r _JAKIM_FETCH_SH_INCLUDED="true"

: "${USER:=$(id -un)}"

# --- File locations -----------------------------------------------------
# RENAMED from FILE1/FILE2/FILE3 (old xmonad-config names) to self-describing
# names. FILE2 (old one-line xmobar-formatted result) is GONE -- that job now
# belongs to bin/waktusolat-render-xmobar reading NEUTRAL_DATA_FILE.
#
# These top-level defaults are single-zone, $USER-scoped, and only meant for
# waktusolat-cli's simple ad-hoc "just fetch me one zone right now" use.
# waktusolat-fetchd calls init_waktusolat_paths() below instead, since it
# needs zone-aware paths (a host may run more than one zone) and a
# configurable NEUTRAL_DATA_FILE directory (/var/lib on the aggregator host,
# /var/cache on every other host -- see module/nixos-*.nix).
RAW_FETCH_FILE="/tmp/${USER}-waktusolat-raw.json"        # was: FILE1
RAW_BACKUP_FILE="/tmp/${USER}-waktusolat-raw.json.bak"   # was: FILE3
NEUTRAL_DATA_FILE="/tmp/${USER}-waktusolat-data.json"    # NEW: canonical output, DE-agnostic

# init_waktusolat_paths <zone> <data_dir>
# Overrides RAW_FETCH_FILE/RAW_BACKUP_FILE/NEUTRAL_DATA_FILE to be specific
# to <zone>, with the neutral output written under <data_dir>/<zone>.json.
# Scratch files (raw fetch + backup) stay under /tmp, keyed by zone so two
# zones running on the same host (or same $USER) don't clobber each other.
init_waktusolat_paths() {
    local zone="$1"
    local data_dir="$2"
    RAW_FETCH_FILE="/tmp/${USER}-waktusolat-raw-${zone}.json"
    RAW_BACKUP_FILE="/tmp/${USER}-waktusolat-raw-${zone}.json.bak"
    NEUTRAL_DATA_FILE="${data_dir}/${zone}.json"
    log_debug "init_waktusolat_paths: zone=${zone} data_dir=${data_dir} NEUTRAL_DATA_FILE=${NEUTRAL_DATA_FILE}"
}

# --- Global state (populated by extractData, consumed by checkData /
# impure_write_neutral_json) ---------------------------------------------
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

# fetchDataZone <zone>
# Ported verbatim from waktusolatlib.sh (the newer, CloudFront-403-aware version).
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

# extractData: parse RAW_FETCH_FILE (JAKIM JSON) into NAMASOLAT/MASASOLAT/ZON/etc.
# Ported verbatim from waktusolatlib.sh's jq-based extractData().
extractData() {
    log_debug "Start extractData()"

    local internal_data
    internal_data=$(jq -r '.prayerTime[0] | to_entries | .[] | "\(.key),\(.value)"' "$RAW_FETCH_FILE" 2>/dev/null)

    local meta_data
    meta_data=$(jq -r '"serverTime,\(.serverTime)\nzone,\(.zone)"' "$RAW_FETCH_FILE" 2>/dev/null)

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

# checkData: validate that extractData() produced exactly the 7 expected
# prayer entries, in the expected order. Ported verbatim.
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
    log_debug "Get previous backup fetched source from file ${RAW_BACKUP_FILE}"
    cat "$RAW_BACKUP_FILE" > "$RAW_FETCH_FILE"
    log_debug "End getOldGoodFetchData()"
}

# --- NEW: neutral JSON output, DE-agnostic ------------------------------

# pure_build_prayers_json: turn NAMASOLAT[]/MASASOLAT[] into a JSON array.
# "pure" in the sense that it only reads globals and returns a string --
# it performs no file I/O of its own (jq itself has no side effects here).
pure_build_prayers_json() {
    local json="[]"
    local i
    for i in "${!NAMASOLAT[@]}"; do
        json=$(jq -c --arg name "${NAMASOLAT[$i]}" --arg time "${MASASOLAT[$i]}" \
            '. + [{"name_bm":$name,"time":$time}]' <<< "$json")
    done
    echo "$json"
}

# impure_write_neutral_json: write NEUTRAL_DATA_FILE atomically (write to a
# temp file, then `mv` -- mv within the same /tmp filesystem is an atomic
# rename, so a renderer can never read a half-written file).
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

    mv "$out_tmp" "$NEUTRAL_DATA_FILE"

    log_debug "Wrote ${NEUTRAL_DATA_FILE}"
    log_debug "End impure_write_neutral_json()"
}
