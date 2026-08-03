#!/usr/bin/env bash
# lib/format-helpers.sh
#
# PORTED from xmonad-config-NajibMalaysia bin/lib/waktusolatlib.sh -- these
# are the pure display-formatting helpers (Hijri/Gregorian month names, day
# names) that any renderer (xmobar, waybar, ...) may want. They are
# deliberately separated from lib/jakim-fetch.sh: the fetcher has no reason
# to know how to spell "Ogos" in Bahasa Malaysia.
#
# All functions here are pure: same input always gives same output, no I/O,
# no globals read/written (they don't even call log_debug, unlike most of
# the old codebase, precisely so this file has zero dependency on logger.sh
# and can be sourced standalone / unit-tested trivially).

[[ "${_FORMAT_HELPERS_SH_INCLUDED:-}" == "true" ]] && return
declare -r _FORMAT_HELPERS_SH_INCLUDED="true"

# namaBulanH <nomborBulan 01-12> [short|long]
namaBulanH() {
    local noBulanH="$1"
    local ntype="${2:-short}"

    case "$noBulanH" in
        "01") [[ "$ntype" == "long" ]] && echo "Muharam" || echo "Mhram" ;;
        "02") echo "Safar" ;;
        "03") [[ "$ntype" == "long" ]] && echo "Rabiulawal" || echo "Rbawl" ;;
        "04") [[ "$ntype" == "long" ]] && echo "Rabiulakhir" || echo "Rbakh" ;;
        "05") [[ "$ntype" == "long" ]] && echo "Jamadilawal" || echo "Jmawl" ;;
        "06") [[ "$ntype" == "long" ]] && echo "Jamadilakhir" || echo "Jmakh" ;;
        "07") echo "Rejab" ;;
        "08") [[ "$ntype" == "long" ]] && echo "Saaban" || echo "Sy3bn" ;;
        "09") [[ "$ntype" == "long" ]] && echo "Ramadan" || echo "Rmdan" ;;
        "10") [[ "$ntype" == "long" ]] && echo "Syawal" || echo "Syawl" ;;
        "11") [[ "$ntype" == "long" ]] && echo "Zulkaedah" || echo "Zlkdh" ;;
        "12") [[ "$ntype" == "long" ]] && echo "Zulhijjah" || echo "Zlhjh" ;;
        *)    echo "eh" ;;
    esac
}

# namaBulanM <nomborBulan 01-12>
namaBulanM() {
    local noBulanM="$1"
    case "$noBulanM" in
        "01") echo "January" ;;   "02") echo "February" ;;
        "03") echo "March" ;;     "04") echo "April" ;;
        "05") echo "May" ;;       "06") echo "June" ;;
        "07") echo "July" ;;      "08") echo "August" ;;
        "09") echo "September" ;; "10") echo "October" ;;
        "11") echo "November" ;;  "12") echo "December" ;;
        *)    echo "eh" ;;
    esac
}

# nomHari <English day name, e.g. "Monday"> -> 1=Sunday .. 7=Saturday
nomHari() {
    local namaHari="$1"
    case "$namaHari" in
        "Sunday")    echo "1" ;;
        "Monday")    echo "2" ;;
        "Tuesday")   echo "3" ;;
        "Wednesday") echo "4" ;;
        "Thursday")  echo "5" ;;
        "Friday")    echo "6" ;;
        "Saturday")  echo "7" ;;
        *)           echo "eh" ;;
    esac
}

# nomNextHari <nomborHari 1-7> -> next day number, wrapping 7 -> 1
nomNextHari() {
    local nextDay=$(( $1 + 1 ))
    (( nextDay == 8 )) && nextDay=1
    echo "$nextDay"
}

# namaHariBM <nomborHari 1-7> -> day name in Bahasa Malaysia
namaHariBM() {
    local nomHari="$1"
    case "$nomHari" in
        1) echo "Ahad" ;;   2) echo "Isnin" ;;
        3) echo "Selasa" ;; 4) echo "Rabu" ;;
        5) echo "Khamis" ;; 6) echo "Jumaat" ;;
        7) echo "Sabtu" ;;
    esac
}
