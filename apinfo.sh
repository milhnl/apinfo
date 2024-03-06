#!/usr/bin/env sh
set -eu

ifname() {
    printf '%s\n' /sys/class/net/*/wireless | awk -F'/' '/^[^*]*$/{ print $5 }'
}

lowercase_vars() {
    sed -e 'h;s/:.*//' \
        -e 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/' \
        -e 'x;s/[^:]*://;H;x;s/\n/:/'
}

apinfo() {
    case "$(uname -s)" in
    Darwin)
        PATH="$PATH:/System/Library/PrivateFrameworks/Apple80211.framework$(
            )/Versions/Current/Resources"
        sudo airport -I
        ;;
    Linux)
        iw dev "$(ifname)" link
        ;;
    esac \
        | sed '
            s/:\s*/:/g
            s/^ *//;s/^\s*//
            s/.*\([0-9a-f:]\{17\}\).*/BSSID:\1/
            s/\(-[0-9]*\) dBm/\1/
        ' \
        | lowercase_vars \
        | awk -v OFS='\t' '
            {
                o[substr($0, 0, index($0, ":") - 1)] = \
                    substr($0, index($0, ":") + 1);
            }
            END {
                if (o["signal"] == "") {
                    o["snr"] = o["agrctlnoise"] - o["agrctlrssi"]
                } else {
                    #Maybe this is actually the RSSI?
                    o["snr"] = o["signal"]
                }
                if (o["channel"] == "") {
                    if (o["freq"] > 2401 && o["freq"] < 2495) {
                        o["channel"] = (o["freq"] - 2407) / 5
                    } else {
                        o["channel"] = o["freq"]
                    }
                }
                print o["bssid"], o["snr"], o["channel"], o["ssid"]
            }
        '
}

apinfo "$@"