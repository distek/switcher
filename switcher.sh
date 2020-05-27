#!/bin/bash

trap SIGINT SIGHUP SIGKILL
switcherCache=$HOME/.cache/switcher
serverCount=$(cat $switcherCache/serverCount)
scriptLoc=$(cat $switcherCache/.location)
arg=$1

rx='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'

scriptVersion="1.0.1"

if [[ $(id -u) != 0 ]]; then
    echo "Run as root."
    exit 2
fi

ASKPASS=$(cat $switcherCache/askpass)

sepLine() { 

    echo ""
    printf '=%.0s' $(eval echo {1..$(tput cols)}) 
    echo ""

}

print_version(){
    echo "
    switcher - VPN-switching cli utility written for the PIA vpn service
    Written by distek 2020
    Version: $scriptVersion
    "
}

ufw_set(){

    echo -e "Creating UFW rules for this IP...\n"
    echo ""
    printf "Resetting firewall settings.              "
    yes | sudo ufw reset >/dev/null
    printf "\rSetting default deny incoming.          "
    yes | sudo ufw default deny incoming >/dev/null
    printf "\rSetting default deny outgoing.          "
    yes | sudo ufw default deny outgoing >/dev/null
    printf "\rSetting traffic on tun0 as allowed.     "
    yes | sudo ufw allow out on tun0 from any to any >/dev/null
    printf "\rSetting special rules.                  "
#    yes | sudo ufw allow in on enp37s0 from 192.168.1.100
#    yes | sudo ufw allow in on enp37s0 from 192.168.1.111
#    yes | sudo ufw allow out on enp37s0 from 192.168.1.100
#    yes | sudo ufw allow out on enp37s0 from 192.168.1.111
## Rules set with the special_rules() function
# %REPLACE%


    printf "\rSetting firewall to enabled.            "
    yes | sudo ufw enable >/dev/null
    printf "\rComplete.                               \n"

}

reset_allow_ufw() {
    printf "Resetting firewall settings.            "
    yes | sudo ufw reset >/dev/null
    printf "\rSetting default allow incoming.         "
    yes | sudo ufw default allow incoming >/dev/null
    printf "\rSetting default allow outgoing.         "
    yes | sudo ufw default allow outgoing >/dev/null
    printf "\rSetting firewall to enabled..           "
    yes | sudo ufw enable >/dev/null
}

off(){
    echo "Resetting FW rules (unprotected)."
    reset_allow_ufw
    printf "\rComplete.                               \n"
    echo "Done."
    VPN_DOWN=$(nmcli -t -f NAME connection show --active | grep PIA)
    echo "Currently connected to $VPN_DOWN"
    echo ""
    nmcli con down "$VPN_DOWN"
    echo -e "VPN has been turned off and you're now unprotected.\n"
}


quick_choice(){
    echo "Please choose your 'quick' choice from the list below:"
    cat  $switcherCache/menu.txt
    read -p "Choice: " QUICK_CHOICE
    if [[ $QUICK_CHOICE < 1 || $QUICK_CHOICE > $serverCount ]]; then
        echo "I didn't understand that choice"
        echo "Returning to main menu"
        sleep 1
        main_menu
    else
        echo $QUICK_CHOICE > $switcherCache/quick
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
    else
        continue
    fi

    if [[ ${#accessIPs[@]} < 2 ]]; then
        sed -i "s/#\ %REPLACE%/\ \ \ \ yes\ \|\ sudo\ ufw\ allow\ in\ from\ ${accessIPs[0]}\ \>\/dev\/null\n#\ %REPLACE%/" $scriptLoc
    else
        for i in $(eval echo {0..${#accessIPs[@]}}); do
            sed -i "s/#\ %REPLACE%/\ \ \ \ yes\ \|\ sudo\ ufw\ allow\ in\ from\ ${accessIPs[$i]}\ \>\/dev\/null\n#\ %REPLACE%/" $scriptLoc
        done
    fi

}

quick(){
    if [[ $(wc -l $switcherCache/quick 2> /dev/null | cut -d' ' -f1) < 1 ]]; then
        quick_choice
        quick
    else
        echo "Resetting FW rules (unprotected)."
        reset_allow_ufw
        VPN_UUID=$(sed "$(cat $switcherCache/quick)q;d" $switcherCache/vpn-uuid-list | cut -d':' -f2)
        VPN_DOWN=$(nmcli -t -f NAME connection show --active | grep PIA)
        echo "Currently connected to $VPN_DOWN"
        echo ""
        nmcli con down "$VPN_DOWN"

        if [[ $ASKPASS == "0" ]]; then
            nmcli con up $VPN_UUID
        elif [[ $ASKPASS == "1" ]]; then
            nmcli con up $VPN_UUID --ask
        else
            sshpass -v -P "Password: (vpn.secrets.password): " | sudo -E gpg -qd $switcherCache/vpn.secrets | nmcli con up $VPN_UUID --ask
            
        fi

        sleep 1
        
        echo "Getting VPN IP from WTFISMYIP.COM"
        VPN_IP=$(curl -s https://wtfismyip.com/text)
        echo -e "Your IP is showing as $VPN_IP\n"
        ufw_set
        exit 0
    fi
}

main(){
    reset_allow_ufw
    if [[ $1 == "" ]]; then
        echo -e "\n\n\nEntering main menu.\n"
        cat $switcherCache/menu.txt 
        read -p "Choice: " VPN_CHOICE
        
        if [[ $VPN_CHOICE < 1 || $VPN_CHOICE > $(( $serverCount + 1 )) ]]; then
            echo "I didn't understand that choice"
            echo "Returning to main menu"
            sleep 1
            main_menu
        fi
        
        if [[ $VPN_CHOICE == $(( $serverCount + 1 )) ]]; then
        	VPN_CHOICE=$(shuf -i 1-$serverCount -n 1)
        fi
        echo ""
        echo "Selected option $VPN_CHOICE"
        echo ""
    else
        VPN_CHOICE=$1
    fi
    VPN_UUID=$(sed "${VPN_CHOICE}q;d" $switcherCache/vpn-uuid-list)
    VPN_DOWN=$(nmcli -t -f NAME connection show --active | grep PIA)
    echo "Currently connected to $VPN_DOWN"
    echo ""
    nmcli con down "$VPN_DOWN"

    if [[ $ASKPASS == "0" ]]; then
        nmcli con up $VPN_UUID
    elif [[ $ASKPASS == "1" ]]; then
        nmcli con up $VPN_UUID --ask
    else
        sshpass -v -P "Password: (vpn.secrets.password): " | sudo -E gpg -qd $switcherCache/vpn.secrets | nmcli con up $VPN_UUID --ask
    fi

    sleep 1
    echo "Getting VPN IP from WTFISMYIP.COM"
    VPN_IP=$(curl -s https://wtfismyip.com/text)
    echo -e "Your IP is showing as $VPN_IP\n"
    ufw_set
    exit 0
}

print_help(){
    echo "
Usage:
    -c   --quick-choice   Change the quick server number
    -f   --full           Full server menu
    -h   --help           Print this help
    -p   --print          Print full server menu and exit
    -q   --quick          Use 'quick choice' server
    -r   --rules          Specify whitelisted IPs(allowed to access the host)
    -s n --server n       Use server 'n'
    -V   --version        Print version info
    "
}

main_menu() {
if [[ -f $switcherCache/vpn-uuid-list ]]; then
    if [[ $1 == "" ]]; then
        sepLine
	    echo "
Which mode would you like?
1. Quick
2. Full
3. Off
4. Choose 'Quick' server
5. Whitelist IPs"
        echo ""
        read -p "Choice: " initChoice
        case $initChoice in
            1) quick;;
            2) main;;
            3) off;;
            4) quick_choice;;
	        5) special_rules;;
            *) echo "I didn't understand that. Exiting."
               exit 1;;
        esac
    else
        case $1 in
            -c|--quick-choice) quick_choice;;
            -f|--full) main;;
            -h|--help) print_help;;
            -p|--print) cat $switcherCache/menu.txt;;
            -q|--quick) quick;;
	        -r|--rules) special_rules;;
            -s|--server) main $*;; 
            -V|--version) version;;
            *) print_help
               exit 1;;
       esac
    fi
else
    echo "VPN UUID list is missing."
    echo "Please re-run the installation."
    exit 1
fi
}

main_menu $arg
