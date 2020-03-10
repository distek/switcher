#!/bin/bash

vpnId=()
switcherCache=$HOME/.cache/switcher
scriptName="switcher"
switcherOg=$(pwd)/switcher.sh
switcherLoc=$(pwd)/switcher.sh.tmp

scriptVersion="1.0.1"

cp $switcherOg $switcherLoc

rx='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'

sepLine() { 

    echo ""
    printf '=%.0s' $(eval echo {1..$(tput cols)}) 
    echo ""

}

install_prep() {

    sepLine

    touch .name
    # Make sure nothing has our executable's name yet
    echo "
If you would like to change the name of the script, enter it now.
If you're good with '$scriptName', leave this prompt blank and hit 
enter.
"
    read -p "Name: " scriptNameChoice
    if [[ $scriptNameChoice != "" ]]; then
        if [[ $scriptNameChoice == *[![:ascii:]]* ]]; then
            echo "Non-ASCII text in name."
            sleep 1.25
            echo "Don't be that person."
            sleep 1.25
            sepLine
            install_prep
        else
            scriptName=$scriptNameChoice
        fi
    fi
    if [[ -f /usr/local/bin/$scriptName ]]; then
        echo -e "
Something else is already using the 'switch' name.
Edit this script to change the name if you want, or get rid of whatever's using
that name.

The variable to change is at the top of the script: 'scriptName'

If you installed this script already, run the 'uninstall.sh'. The original name
of the script should be saved in the .name file within the repo's directory.
"
        exit 3
    fi

    if [ ! -d $switcherCache ]; then
        mkdir $switcherCache
    fi
    touch $switcherCache/vpn-uuid-list
    touch $switcherCache/vpn.secrets
    echo "$scriptName" > .name

}

build_menu_items(){

    IFS=$'\n'

    for i in $(nmcli --terse -f all con show | grep ^PIA | awk -F':' '{print $1}' | awk -F'PIA - ' '{print $2}'); do
        vpnId+=("$i")
    done
    echo "${#vpnId[@]}" > $switcherCache/serverCount

    IFS=$' '

}

#Dynamic table of servers, 4 per column
print_menu() {

    IFS=$'\n'
    countIds=${#vpnId[@]}
    IFS=$' '
    for i in $(eval echo {1..$countIds}); do

        if [[ $i < 10 ]]; then
            printf "$i),${vpnId[$(( $i - 1 ))]},"
        else
            printf "$i),${vpnId[$(( $i - 1 ))]},"
        fi

        if [[ $(( $i % 4 )) == 0 ]]; then
            printf '\n'
        fi
        
    done
    printf "$(( $countIds + 1 ))),Random"
    printf '\n'

}

menu_out() {

    build_menu_items
    printf '\n'
    printf '=%.0s' {1..84}
    printf '\n\nChoose a server:\n\n'
    print_menu | column -t -s','
    printf '\n'
    printf '=%.0s' {1..84}
    printf '\n\n'

}

shut_it_down() {

    ACTIVE_VPN=$(nmcli --terse -f all con show | grep -i active | grep -i vpn | awk -F':' '{print $2}')
    nmcli con down $(printf '%q\n' "$ACTIVE_VPN") 2>/dev/null

}

encrypt_secrets() {

    sepLine
    echo ""
    echo "Enter your VPN password: "
    echo "Password will be in clear-text (in memory) until the secrets file is created."
    read -sp "Password: " PASS
    echo -e "\n"
    echo "Enter your password one more time:"
    read -sp "Confirm : " PASS_CONFIRM
    echo -e "
The next password prompt is to lock/unlock your password file, It doesn't have
to be the same as your VPN password."
    if [[ $PASS == $PASS_CONFIRM ]]; then
        if echo $PASS | gpg -c > $switcherCache/vpn.secrets; then
            echo "Success"
        else
            echo "
Error: You need to enable pinentry loopback for this script to work
To do this:
Add the following lines to '/root/.gnupg/gpg.conf':

use-agent
pinentry-mode loopback

And add the following line to /root/.gnupg/gpg-agent.conf:

allow-loopback-pinentry

If you don't want to do this for some reason, I get it, but you'll have to set 
this stuff up manually cause I have enough 'if' statements as it is.

More info:
https://d.sb/2016/11/gpg-inappropriate-ioctl-for-device-errors
"
            PASS="|)0ngz"
            PASS_CONFIRM="|)0ngz"
            exit 1

        fi
    else
        echo "Passwords did not match, try again."
        encrypt_secrets
    fi

    PASS="|)0ngz"
    PASS_CONFIRM="|)0ngz"
    touch $switcherCache/.gpgtrue

}

pass_choice() {

    sepLine
    echo -e "
Do you want to:\n
\t1) enter your password every time, or 
\t2) save it in an encrypted pass-file?
"

    read -p "Choice: " PASS_CHOICE
    
    case $PASS_CHOICE in
        1) PASS="enter";;
        2) encrypt_secrets;;
        *) echo "Try again"
           sleep 2
           pass_choice;;
    esac
}

vpn_uuid_list() {

    sepLine
    echo ""
    echo "Building VPN UUID list"

    nmcli --terse -f all con show | grep "PIA" | cut -d ':' -f 2 > $switcherCache/vpn-uuid-list

    if [[ $(cat $switcherCache/vpn-uuid-list) == "" ]]; then
    echo -e "
Have you ran the pia-nm.sh script?
Double-check by running:

nmcli con show | grep 'PIA'

If that returns a list then try building the list yourself.
It's simply a list of JUST the UUIDs. No names or columns.
The command ran by the script is:

nmcli --terse -f all con show | grep 'PIA' | cut -d ':' -f 2 > $switcherCache/vpn-uuid-list

Continuing
"
    fi

}

special_rules() {


    echo "
Enter in any IP addresses you would like to have access to this box 
while the VPN is active, hit enter after each entry.

Leave prompt blank and hit enter when done.
"

    accessIPs=()

    while true; do
        read -p "IP: " accessIP
        if [[ $accessIP == "" ]]; then
            break
        else
            if [[ $accessIP =~ ^$rx\.$rx\.$rx\.$rx$ ]]; then
                accessIPs+=("$accessIP")
            else
                echo "That wasn't an IP address..."
            fi
        fi
    done

    if [[ ${#accessIPs[@]} == 0 ]]; then
        echo "
You did not enter any IPs.
Want to try again?
"
        read -p "[y/N] " WHOOPS
    
        if [[ $WHOOPS =~ [yY] ]]; then
            special_rules        
        fi
    fi

    # Basically, if n to the above quesiton
    if [[ ${#accessIPs[@]} == 0 ]]; then
        continue
    fi

    if [[ ${#accessIPs[@]} < 2 ]]; then
        sed -i "s/#\ %REPLACE%/\ \ \ \ yes\ \|\ sudo\ ufw\ allow\ in\ from\ ${accessIPs[0]}\ \>\/dev\/null\n#\ %REPLACE%/" $switcherLoc
    else
        for i in $(eval echo {0..${#accessIPs[@]}}); do
            sed -i "s/#\ %REPLACE%/\ \ \ \ yes\ \|\ sudo\ ufw\ allow\ in\ from\ ${accessIPs[$i]}\ \>\/dev\/null\n#\ %REPLACE%/" $switcherLoc
        done
    fi

}

if [[ $(id -u) != 0 ]]; then
    echo "Must be ran as root"
    echo "Exiting."
    exit 1
fi

echo "About to bring down any PIA VPN connection currently active."
echo "Is this okay?"

read -p "[y/N] " SAFE

if [[ $SAFE == "y" ]]; then
    shut_it_down
else
    echo "Exiting. Come back when it's safe to disconnect."
    exit 0
fi

echo "Getting ready..."

install_prep

pass_choice

echo "Getting VPN UUIDs together."

vpn_uuid_list

sepLine

echo ""
echo "Would you like to add any additional IPs to be allowed through the firewall?"

read -p "[y/N] " SPECIAL

if [[ $SPECIAL =~ [yY] ]]; then
    special_rules
fi

sepLine
echo ""

echo "Copying the script over to /usr/local/bin/ as $scriptName"

cp $switcherLoc /usr/local/bin/$scriptName
chmod +x /usr/local/bin/$scriptName

# Generate Menu

menu_out > $switcherCache/menu.txt

echo "/usr/local/bin/$scriptName" > $switcherCache/.location

sepLine

# Post-installation checks

if [ -f /usr/local/bin/$scriptName ]; then
    if [ -f $switcherCache/vpn-uuid-list ];then
        echo -e "Looks like we're good to go!
Run '$scriptName' using sudo if not already root.\n\n"
        rm $switcherLoc
        exit 0
    else
        echo "Missing the vpn-uuid-list!\nYou may have to generate this yourself."
        exit 4
        rm $switcherLoc
    fi
else
    echo -e "Something went wrong!
Switcher was not installed correctly.
Run this using 'bash -x install.sh' to see if any errors occur that weren't
reported before."
    rm $switcherLoc
    exit 5
fi


