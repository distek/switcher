# switcher

VPN switching utility using NetworkManager on Linux for the PIA VPN service.

## Requirements
```
For PIA:
libnsl
lzo
openvpn
pkcs11-helper
networkmanager-openvpn
python2

For switcher:
sshpass
networkmanager
networkmanager-openvpn
iptables
ufw
gpg
```
And `pia-nm.sh` (to install VPN profiles from PIA):
- At this time, this can be acquired via:
    - `wget https://www.privateinternetaccess.com/installer/pia-nm.sh`
    - More info:
        - [Here](https://www.privateinternetaccess.com/helpdesk/guides/linux/alternitive-setups-3/linux-ubuntu-installing-openvpn)
            - I know it talks about Ubuntu, but it's been working fine for me on Arch.


May require additional modification to the gpg config files in `/root`:

- Info found [here](https://d.sb/2016/11/gpg-inappropriate-ioctl-for-device-errors)

- Create and/or Modify /root/.gnupg/gpg.conf
    - `use-agent`
    - `pinentry-mode loopback`


- Create and/or modify /root/.gnupg/gpg-agent.conf:

    - `allow-loopback-pinentry`

## Installation

Run `./install.sh` as root, and follow the prompts

## Uninstall

Run `./uninstall.sh` as root.

## Usage

```
Which mode would you like?
1. Quick
2. Full
3. Off
4. Choose 'Quick' server
5. Whitelist IPs

Choice:
```
Option 1 will use a predefined (or soon to be defined) integer selecting one of the servers in your list

Option 2 will print the menu below:
```
====================================================================================

Choose a server:

1)   AU Melbourne    2)   AU Perth           3)   Austria         4)   AU Sydney
5)   Belgium         6)   CA Montreal        7)   CA Toronto      8)   CA Vancouver
9)   Czech Republic  10)  DE Berlin          11)  DE Frankfurt    12)  Denmark
13)  Finland         14)  France             15)  Hong Kong       16)  Hungary
17)  Ireland         18)  Israel             19)  Italy           20)  Japan
21)  Luxembourg      22)  Mexico             23)  Netherlands     24)  New Zealand
25)  Norway          26)  Poland             27)  Romania         28)  Singapore
29)  Spain           30)  Sweden             31)  Switzerland     32)  UAE
33)  UK London       34)  UK Manchester      35)  UK Southampton  36)  US Atlanta
37)  US California   38)  US Chicago         39)  US Denver       40)  US East
41)  US Florida      42)  US Houston         43)  US Las Vegas    44)  US New York City
45)  US Seattle      46)  US Silicon Valley  47)  US Texas        48)  US Washington DC
49)  US West         50)  Random

====================================================================================

Choice:
```

Please note that this menu is dynamically generated when `install.sh` is ran. Yours will likely be different, but shouldn't change post-installation, unless you run the `pia-nm.sh` script again.

This was discovered when I installed this script on a few of my machines. The pretty list I built was all mixed up and connecting to "US Las Vegas" was now "Poland", etc. Hence the move to a dynamically built list.


Option 3 will turn off all VPN and return your network to a normal state

Option 4 will let you re-select a server for the 'quick' option

Option 5 will allow you to add additional IPs to the "allowed" list.

- The main usage for this would be if you need a host that, for the rest of the internet, is connecting via the VPN, but is still accessible through, say, SSH, from your local LAN.

- Would not recommend adding your gateway as allowed, as that would kind of defeat the purpose of this whole thing.


---

Flags can also be used to get to where you want to go, faster:

```
Usage:
    -c   --quick-choice   Change the quick server number
    -f   --full           Full server menu
    -h   --help           Print this help
    -p   --print          Print full server menu and exit
    -q   --quick          Use 'quick choice' server
    -r   --rules          Specify whitelisted IPs(allowed to access the host)
    -s n --server n       Use server 'n'
    -V   --version        Print version info
```

## Issues
If you happen to find a problem with this, please open a github issue.

## Other Info
This was written in/using Arch Linux. If you have a different system and it works just fine, let me know!

The main point of this is that I wanted a utility for preventing DNS leak, but did not require the PIA GUI app.

All files should be located in `/root/.cache/switcher`

The 'switch' script should be in `/usr/local/bin/`

We might have to switch from UFW at some point, but for right now, it works just fine.

Also, if you have a way to improve upon the script, submit a patch or PR!
