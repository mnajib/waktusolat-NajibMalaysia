#!/usr/bin/env bash
# lib/aggregator-client.sh
#
# NEW. Lets a client-role waktusolat-fetchd ask a waktusolat-aggregator
# instance (e.g. running on nyxora) for already-fetched, already-validated
# prayer-time JSON over the LAN, instead of hitting JAKIM directly. Only the
# aggregator itself should ever be a JAKIM client -- everyone else should be
# an aggregator client.
#
# This file has no dependency on jakim-fetch.sh's globals (NAMASOLAT, ZON,
# etc.) -- it operates purely on files, which keeps the "ask the network"
# and "ask JAKIM" code paths fully independent and easy to test separately.

[[ "${_AGGREGATOR_CLIENT_SH_INCLUDED:-}" == "true" ]] && return
declare -r _AGGREGATOR_CLIENT_SH_INCLUDED="true"

# impure_try_fetch_from_aggregator <base_url> <zone> <timeout_seconds> <dest_file>
#
# On success: writes <dest_file> atomically (temp file + mv), returns 0.
# On any failure (unreachable, timeout, non-2xx, or a response that isn't
# well-formed waktusolat JSON): leaves <dest_file> completely untouched and
# returns 1. Callers MUST treat a non-zero return as "fall back to fetching
# JAKIM directly" -- this function never partially writes dest_file.
impure_try_fetch_from_aggregator() {
    local base_url="$1"
    local zone="$2"
    local timeout="$3"
    local dest_file="$4"

    log_debug "Trying aggregator: ${base_url}/${zone}.json (timeout ${timeout}s)"

    local tmp_file
    tmp_file="$(mktemp "${dest_file}.aggfetch.XXXXXX")"
    # mktemp defaults to 0600, and `mv` below PRESERVES that mode rather
    # than resetting it -- without this chmod, dest_file ends up
    # unreadable by any user except the `waktusolat` service account,
    # defeating the whole "shared by all local users" point of
    # /var/cache/waktusolat. (Found via a real deployment on `asmak`.)
    chmod 0644 "$tmp_file"

    if ! curl -s --fail --max-time "$timeout" "${base_url}/${zone}.json" -o "$tmp_file" 2>>"$LOG_FILE"; then
        log_warn "Aggregator ${base_url} unreachable or returned a non-2xx response for ${zone}"
        rm -f "$tmp_file"
        return 1
    fi

    # Validate shape, not just "is this JSON" -- must look like a real
    # waktusolat neutral-data file (7 prayers, non-null zone), or a
    # misbehaving/misconfigured aggregator could poison dest_file with
    # something structurally wrong that a renderer can't handle.
    if ! jq -e '(.zone != null) and (.prayers | type == "array") and (.prayers | length == 7)' \
            "$tmp_file" > /dev/null 2>&1; then
        log_warn "Aggregator response for ${zone} failed shape validation -- first 200 bytes: $(head -c 200 "$tmp_file" 2>/dev/null | tr '\n' ' ')"
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$dest_file"
    log_debug "Aggregator fetch OK, wrote ${dest_file}"
    return 0
}
