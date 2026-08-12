#!/usr/bin/env bash
# lib/logger.sh
#
# Ported from xmonad-config-NajibMalaysia bin/lib/logger.sh, unchanged logic.
# Only the default LOG_FILE path was renamed to fit this standalone project.

# Guard clause to prevent multiple inclusions of this file
[[ "${_LOGGER_SH_INCLUDED:-}" == "true" ]] && return
declare -r _LOGGER_SH_INCLUDED="true"

BASE_DIR="/tmp"

# Logging levels
LOG_LEVEL_SILENT=0
LOG_LEVEL_ERROR=1
LOG_LEVEL_WARN=2
LOG_LEVEL_INFO=3
LOG_LEVEL_DEBUG=4

# Default log level
LOG_LEVEL=$LOG_LEVEL_INFO

# Default log file (CHANGED: was /tmp/${USER}-xmonad.log)
# Falls back to `id -un` if $USER is unset (e.g. under `set -u`, some
# minimal systemd/container contexts don't export USER).
: "${USER:=$(id -un)}"
LOG_FILE="${BASE_DIR}/${USER}-waktusolat-fetchd.log"

set_log_level() {
    local level="$1"
    case "$level" in
        silent|SILENT) LOG_LEVEL=$LOG_LEVEL_SILENT ;;
        error|ERROR)  LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        warn|WARN|warning|WARNING)   LOG_LEVEL=$LOG_LEVEL_WARN ;;
        info|INFO)   LOG_LEVEL=$LOG_LEVEL_INFO ;;
        debug|DEBUG)  LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        *)      LOG_LEVEL=$LOG_LEVEL_INFO ;;
    esac
}

set_log_file() {
    local file="$1"
    LOG_FILE="$file"
}

get_log_file() {
    echo "$LOG_FILE"
}

reset_log_file() {
    local file="$1"
    cat /dev/null > "$file"
}

# Generic log function
log() {
    local message_level="$1"
    local message="$2"
    local message_level_value=0
    local mode_level_value=$LOG_LEVEL

    case "$message_level" in
        error|ERROR) message_level_value=$LOG_LEVEL_ERROR ;;
        warn|warning|WARN|WARNING)  message_level_value=$LOG_LEVEL_WARN ;;
        info|INFO)  message_level_value=$LOG_LEVEL_INFO ;;
        debug|DEBUG) message_level_value=$LOG_LEVEL_DEBUG ;;
    esac

    if (( mode_level_value >= message_level_value )); then

        local line="$(date "+%F %T") ${message_level}: ${message}"
        echo "$line" >> "$LOG_FILE"
        #[[ "${WAKTUSOLAT_LOG_TO_STDERR:-0}" == "1" ]] && echo "$line" >&2

    fi
}

# Convenience functions
log_error() { log "ERROR" "$1"; }
log_warn()  { log "WARN"  "$1"; }
log_info()  { log "INFO"  "$1"; }
log_debug() { log "DEBUG" "$1"; }
