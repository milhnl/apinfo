# apinfo - Cross-platform WiFi connectivity tool

A simple script that massages the output of your platform's WiFi infrastructure
into an easily readable table of visible access points, so you can find out why
your WiFi does not work.

### Installation

If you put your binaries in `~/.local/bin`:

    PREFIX="$HOME/.local" make install

If you can't figure this out and want to use this tool anyway, message me.

### Dependencies

`apinfo` is designed to work with what's already on your system. That said, it
currently supports `iw` (used in some Linux configurations), a combination of
`wdutil` and CoreWLAN (on macOS >=14.4) and `airport` (standard on macOS
<14.4). Adding support for NetworkManager is quite easy, but I don't use it.

### Usage

There are 4 different kinds of output:

- `apinfo` – without arguments, apinfo shows only the access point you're
  currently connected to.
- `apinfo --roam` – show all access points for the network you're on.
- `apinfo --roam SSID` – show all access points for the specified network.
- `apinfo --all` – show all access points for all networks.

`--all` would show something like this:

    AP Upstairs        -36  1   Home
    AP Upstairs        -44  36  Home
    Router             -53  1   Home
    01:23:45:67:89:ab  -72  1   Neighbors
    Router             -75  36  Home
    23:01:45:67:89:ab  -80  64  Other neighbors
    89:45:23:01:cd:67  -85  6   Someone's solar panel
    45:23:01:cd:67:89  -90  64  A printer?
    23:01:45:67:89:ab  -91  1   Novelty network name

There's four columns (when you don't pipe the output), and in your terminal the
second row would be highlighted, let's see what it all means and how you can
use it.

- The highlighted row is the access point you're currently connected to.
- The first column shows the access points. Notice how there are some that do
  not show the BSSID but a name. `apinfo` allows you to have a configuration
  file mapping BSSIDs to names, so you can more easily recognize them. By the
  way, the BSSID is the MAC address (a fingerprint) of the access point's WiFi
  hardware. Which means that dual-band (i.e. combined 2.4 and 5 GHz) access
  points will show up twice.
- The second column shows the signal strength, in dBm. This is called RSSI. A
  higher (less negative) number is better.
- After that, the channel. Channels 1-14 are 2.4 GHz, and 32-177 in the 5 Ghz
  range.
- Last but not least, the SSIDs: network names.

I mostly use this walking around with my laptop, finding out if I'm connected
to the right access point, roaming (reconnecting to a different access points)
works the way I expect it, and the signal strength is good enough. If anything
is wrong, move your access point and try again.

### Configuration

The configuration file can be found at:

- `$XDG_CONFIG_HOME/apinfo/addresses` which defaults to
- `~/.config/apinfo/addresses`

It's a file containing mappings between BSSIDs and names, like so:

    80:ab:90:bc:de:01 Router
    80:ab:90:bc:de:02 Router
    43:21:ba:fe:aa:21 AP Upstairs
    43:21:ba:fe:aa:22 AP Upstairs

Every line starts with the BSSID, then a space or a tab, and the rest of the
line is the name you want to give to it.

### Notes/bugs

macOS does not expose BSSIDs anymore. There is a solution involving
entitlements and a GUI application, which I don't feel like figuring out right
now. This means that `apinfo` can't name any access points.
