#!/usr/bin/env sh
set -eu

die() { printf '%s\n' "$*" >&2; exit 1; }
exists() { command -v "$1" >/dev/null 2>&1; }

ifname() {
    printf '%s\n' /sys/class/net/*/wireless | awk -F'/' '/^[^*]*$/{ print $5 }'
}

apinfo_airport_all() {
    sudo airport -s \
        | awk -vOFS='\t' '
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
                print bssid, rssi, channel, ssid
            }
        '
}

apinfo_airport_con() {
    sudo airport -I \
        | awk -vOFS='\t' '
            / +BSSID: / { bssid = $0; sub(/.*: /, "", bssid); next }
            / +agrCtlRSSI: / { rssi = $0; sub(/.*: /, "", rssi); next }
            / +channel: / { channel = $0; sub(/.*: /, "", channel); next }
            / +SSID: / { ssid = $0; sub(/.*: /, "", ssid); next }
            END {
                print bssid, rssi, channel, ssid
            }
        '
}

apinfo_iw() {
    if [ "${1:-}" = --all ] && shift; then
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
                    print bssid, rssi, channel, ssid
                    bssid = ""
                    rssi = ""
                    channel = ""
                    ssid = ""
                }
                bssid = substr($0, 5, 17)
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
                sub(/ dBm$/, "", rssi);
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
                print bssid, rssi, channel, ssid
            }
        '
}

apinfo_usage() {
    printf '%s\n' \
        'Usage: apinfo [--all]' \
        '' \
        'List WiFi access points with signal information' \
        '' \
        'Options:' \
        '  --all          List all access points' \
        '' \
        'When no options are given, show only currently' \
        'connected access point.'
}

apinfo() {
    [ "${1:-}" = --all ] || [ $# -eq 0 ] \
        || die "$(apinfo_usage)"
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME-$HOME/.config}"
    PATH="$PATH:/System/Library/PrivateFrameworks/Apple80211.framework$(
        )/Versions/Current/Resources"
    if exists airport; then
        if [ "${1:-}" = --all ] && shift; then
            apinfo_airport_all
        else
            apinfo_airport_con
        fi
    elif exists iw; then
        apinfo_iw "$@"
    else
        die "ERROR: apinfo can only work with iw or airport"
    fi \
        | sort -t"$(printf \\t)" -k2 \
        | cfg="$XDG_CONFIG_HOME/apinfo/addresses" awk -vFS='\t' -vOFS='\t' '
            BEGIN {
                if (!system("[ -r \"$cfg\" ]")) {
                    while ((getline line <ENVIRON["cfg"]) > 0) {
                        i = match(line, /[ \t]/)
                        addresses[substr(line, 1, i - 1)] = substr(line, i + 1)
                    }
                }
            }
            {
                print ($1 in addresses ? addresses[$1] : $1), $2, $3, $4
            }
        '
}

apinfo "$@"
