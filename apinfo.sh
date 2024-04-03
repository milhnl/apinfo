#!/usr/bin/env sh
set -eu

die() { printf '%s\n' "$*" >&2; exit 1; }
exists() { command -v "$1" >/dev/null 2>&1; }

ifname() {
    printf '%s\n' /sys/class/net/*/wireless | awk -F'/' '/^[^*]*$/{ print $5 }'
}

apinfo_airport_all() {
    sudo airport -s \
        | awk -vOFS='\t' -vnow="$(apinfo_airport_con)" '
            BEGIN {
                split(now, now_a)
                bssid_now = now_a[1]
            }
            NR == 1 {
                ssid_i = index($0, "SSID")
                bssid_i = index($0, "BSSID")
                rssi_i = index($0, "RSSI")
                channel_i = index($0, "CHANNEL")
                next;
            }
            {
                bssid = substr($0, bssid_i, 17)
                rssi = substr($0, rssi_i, 3)
                channel = substr($0, channel_i)
                sub(/ .*/, "", channel)
                ssid = substr($0, 1, ssid_i + 3)
                sub(/^ */, "", ssid)
                con = bssid_now == bssid ? "*" : ""
                print con, bssid, rssi, channel, ssid
            }
        '
}

apinfo_airport_con() {
    sudo airport -I \
        | awk -vOFS='\t' '
            / +BSSID: / {
                bssid = $0
                sub(/.*: /, "", bssid)
                bssid = ":" bssid ":"
                while (match(bssid, /(^|:)[0-9a-f](:|$)/)) {
                    bssid = substr(bssid, 1, RSTART) "0" \
                        substr(bssid, RSTART + 1)
                }
                bssid = substr(bssid, 2, length(bssid) - 2)
                next
            }
            / +agrCtlRSSI: / { rssi = $0; sub(/.*: /, "", rssi); next }
            / +channel: / { channel = $0; sub(/.*: /, "", channel); next }
            / +SSID: / { ssid = $0; sub(/.*: /, "", ssid); next }
            END {
                print con, bssid, rssi, channel, ssid
            }
        '
}

apinfo_iw() {
    if [ "${1:-}" = --all ] || [ "${1:-}" = --roam ]; then
        sudo iw dev "$(ifname)" scan
    else
        iw dev "$(ifname)" link
    fi \
        | awk -vOFS='\t' '
            /^Connected to / {
                bssid = substr($0, 14, 17)
                next
            }
            /^BSS/ {
                if (bssid) {
                    print con, bssid, rssi, channel, ssid
                    bssid = ""
                    rssi = ""
                    channel = ""
                    ssid = ""
                    con = ""
                }
                bssid = substr($0, 5, 17)
                if ($0 ~ / -- associated$/)
                    con = "*"
                next
            }
            /\t+SSID: / {
                ssid = $0; sub(/.*: /, "", ssid)
                if (ssid ~ /(\\x00)+/)
                    ssid = "(hidden)"
                next
            }
            /\t+signal: / {
                rssi = $0; sub(/.*: /, "", rssi);
                sub(/(\.00) dBm$/, "", rssi);
                next
            }
            /\t+freq: / {
                freq = $0; sub(/.*: /, "", freq)
                if (freq > 2401 && freq < 2495) {
                    channel = (freq - 2407) / 5
                } else if (freq >= 5160 && freq <= 5885) {
                    channel = (freq - 5160) / 5 + 32
                }
                next
            }
            /.*\* primary channel: / {
                channel = $0; sub(/.*: /, "", channel); next
            }
            END {
                print con, bssid, rssi, channel, ssid
            }
        '
}

apinfo_usage() {
    printf '%s\n' \
        'Usage: apinfo [--all|--roam [ssid]]' \
        '' \
        'List WiFi access points with signal information' \
        '' \
        'Options:' \
        '  --all          List all access points' \
        '  --roam [ssid]  List those matching SSID, which' \
        '                 defaults to currently connected' \
        '' \
        'When no options are given, show only currently' \
        'connected access point.'
}

apinfo() {
    [ "${1:-}" = --all ] || [ "${1:-}" = --roam ] || [ $# -eq 0 ] \
        || die "$(apinfo_usage)"
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME-$HOME/.config}"
    PATH="$PATH:/System/Library/PrivateFrameworks/Apple80211.framework$(
        )/Versions/Current/Resources"
    if [ -t 1 ]; then
        export APINFO_PRETTY_OUTPUT="${APINFO_PRETTY_OUTPUT-true}"
    fi
    if [ "${1-}" = --roam ]; then
        export APINFO_FILTER_SSID="${2-}" #Empty/no argument is current SSID
    fi
    if exists airport; then
        if [ "${1:-}" = --all ] || [ "${1:-}" = --roam ]; then
            apinfo_airport_all
        else
            apinfo_airport_con
        fi
    elif exists iw; then
        apinfo_iw "$@"
    else
        die "ERROR: apinfo can only work with iw or airport"
    fi \
        | sort -r \
        | cfg="$XDG_CONFIG_HOME/apinfo/addresses" awk -vFS='\t' -vOFS='\t' '
            BEGIN {
                if (!system("[ -r \"$cfg\" ]")) {
                    while ((getline line <ENVIRON["cfg"]) > 0) {
                        i = match(line, /[ \t]/)
                        addresses[substr(line, 1, i - 1)] = substr(line, i + 1)
                    }
                }
            }
            FNR == 1 && ("APINFO_FILTER_SSID" in ENVIRON) {
                if (ENVIRON["APINFO_FILTER_SSID"])
                    filter_ssid = ENVIRON["APINFO_FILTER_SSID"]
                else
                    filter_ssid = $1 == "*" ? $5 : exp(70) #invalid ssid
            }
            !filter_ssid || filter_ssid == $5 {
                if ("APINFO_PRETTY_OUTPUT" in ENVIRON && \
                        ENVIRON["APINFO_PRETTY_OUTPUT"] != "false")
                    printf( \
                        $1 \
                            ? "\033[7m%s\t%s\t%s\t%s\033[0m\n" \
                            : "\033[0m%s\t%s\t%s\t%s\033[0m\n", \
                        ($2 in addresses ? addresses[$2] : $2), $3, $4, $5 \
                    )
                else
                    print $0
            }
        ' \
        | if [ -n "${APINFO_PRETTY_OUTPUT-}" ]; then
            sort -k2nr | column -ts "$(printf \\t)"
        else
            sort -k3nr -t "$(printf \\t)"
        fi
}

apinfo "$@"
