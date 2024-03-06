#!/usr/bin/env sh
set -eu

ifname() {
    printf '%s\n' /sys/class/net/*/wireless | awk -F'/' '/^[^*]*$/{ print $5 }'
}

apinfo_airport() {
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
    iw dev "$(ifname)" link \
        | awk -vOFS='\t' '
            /^Connected to / {
                bssid = substr($0, 14, 17)
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
            END {
                print bssid, rssi, channel, ssid
            }
        '
}

apinfo() {
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME-$HOME/.config}"
    case "$(uname -s)" in
    Darwin)
        PATH="$PATH:/System/Library/PrivateFrameworks/Apple80211.framework$(
            )/Versions/Current/Resources"
        apinfo_airport
        ;;
    Linux)
        apinfo_iw
        ;;
    esac \
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
