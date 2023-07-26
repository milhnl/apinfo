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
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME-$HOME/.config}"
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
        | cfg="$XDG_CONFIG_HOME/apinfo/addresses" awk -v OFS='\t' '
            BEGIN {
                if (!system("[ -r \"$cfg\" ]")) {
                    while ((getline line <ENVIRON["cfg"]) > 0) {
                        i = match(line, /[ \t]/)
                        addresses[substr(line, 1, i - 1)] = substr(line, i + 1)
                    }
                }
            }
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
                if (match(o["bssid"], " \\*$" )) {
                    o["bssid"] = substr(o["bssid"], 1, length(o["bssid"]) - 2)
                    o["connected"] = " *"
                }
                if (o["bssid"] in addresses) {
                    o["id"] = addresses[o["bssid"]]
                } else {
                    o["id"] = o["bssid"]
                }
                print (o["id"] o["connected"]), o["snr"], o["channel"], o["ssid"]
                for (i in o) delete o[i]
            }
            END { if (o["bssid"]) output(); }
        '
}

apinfo "$@"
