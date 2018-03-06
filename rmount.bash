#!/usr/bin/env bash

# Exit on error
set -e


########################
#                      #
#    DEPENDENCIES      #
#                      #
########################
# jq nmap sshfs cifs-utils


########################
#                      #
#    OPTION VARS       #
#                      #
########################
CONFIGFILE="config.json"


############################################
#                                          #
# How to setup shared folder on windows    #
#                                          #
############################################
#
# Link: https://www.howtogeek.com/176471/how-to-share-files-between-windows-and-linux/
#
#

PATHCONFIG="$PWD/$CONFIGFILE"

## COLORS
RED='\033[00;31m'
GREEN='\033[00;32m'
YELLOW='\033[00;33m'
BLUE='\033[00;34m'
PURPLE='\033[00;35m'
CYAN='\033[00;36m'
LIGHTGRAY='\033[00;37m'

LRED='\033[01;31m'
LGREEN='\033[01;32m'
LYELLOW='\033[01;33m'
LBLUE='\033[01;34m'
LPURPLE='\033[01;35m'
LCYAN='\033[01;36m'
WHITE='\033[01;37m' # No color
NC='\033[0m' # No Color

function help()
{
    echo -e "$0 $LYELLOW<name>$NC"
    echo ""
    echo -e " Names: "
    for vm in $(jq -r ".Hosts | keys[]" $PATHCONFIG); do
        echo -e -n " $LYELLOW$vm$NC"
    done

    echo ""
    echo ""

    echo -e "$0 scan $LYELLOW<options>$NC <network range>"
    echo ""
    echo -e " Options:"
    echo -e "$LYELLOW ssh samba$NC"
    exit
}

# $1 --> Key
function get_default_value()
{
    local RET=$(jq -r ".Default."$1 $PATHCONFIG)
    echo $RET
}


# $1 --> Hostname-key
function check_key()
{
    local RET=$(jq -r ".Hosts."$1 $PATHCONFIG)

    if [ "$RET" == "null" ]; then
        echo "False"
    fi

    echo "True"
}

# $1 --> Hostname-key
function is_ssh()
{
    local RET=$(jq -r ".Hosts."$1".Method" $PATHCONFIG)

    if [ "$RET" == "Ssh" ] || [ "$RET" == "ssh" ]; then
        echo "True"
        return 1
    fi

    echo "False"
    return 0
}

# $1 --> Hostname-key
function is_samba()
{
    local RET=$(jq -r ".Hosts."$1".Method" $PATHCONFIG)

    if [ "$RET" == "Samba" ] || [ "$RET" == "samba" ]; then
        echo "True"
        return 1
    fi

    echo "False"
    return 0
}


#
#   Tries to find the key in the hostname-key body.
#   If not found search in Default body.
#
# $1 --> Hostname-key $2 Key
function get_value()
{
    local RET=$(jq -r ".Hosts."$1"."$2 $PATHCONFIG)
    if [ "$RET" == "null" ]; then
        local RET=$(get_default_value $2)
        if [ "$RET" == "null" ]; then
            echo "Error in config: .Hosts."$1"."$2" OR Default "
            exit
        fi
    fi
    echo $RET
}


# Check if script is executed as root
if [[ $EUID -ne 0 ]]; then
   echo "[-] This script must be run as root" 1>&2
   exit 1
fi

# Check if config file exists
if [ ! -f "$PATHCONFIG" ]; then
    echo -e "$LRED[-] Configfile '$PATHCONFIG' not found$NC"
    exit 1
fi

if [ "$1" == "" ]; then
    help
fi

# Check if it should scan the network
if [ "$1" == "scan" ]; then

    if [ "$2" == "" ] || [ "$3" == "" ]; then
        echo "$0 scan <option> <network range>"
        echo "Options: ssh samba"
        exit
    fi

    if [ "$2" == "samba" ]; then
        echo "Scan network $3 for open samba ports"
        nmap -n -p445 $3 -oG -
        exit
    fi

    if [ "$2" == "ssh" ]; then
        echo "Scan network $3 for open ssh ports"
        nmap -n -sV -p22 $3 -oG -
        exit
    fi

fi

# Use ssh method
if [ "$(is_ssh $1)" == "True" ] && [ "$(check_key $1)" == "True" ]; then

    MOUNTPOINT=$(get_value $1 "Mountpoint")
    MOUNTUSER=$(get_value $1 "MountUser")
    VMUSER=$(get_value $1 "VMUser")
    VMFOLDER=$(get_value $1 "VMFolder")
    IP=$(get_value $1 "HostName")
    IDENTITYFILE=$(get_value $1 "IdentityFile")



    if grep -qsw "$MOUNTPOINT/$1" "/proc/mounts"; then
        echo -e "$LRED[-] Location $MOUNTPOINT/$1 already mounted$NC"
        exit
    fi

    if [ ! -d  "$MOUNTPOINT/$1" ]; then
        mkdir $MOUNTPOINT/$1
        chown -R $MOUNTUSER: $MOUNTPOINT/$1
    fi
    echo "[*] sshfs -o allow_other -o  uid=$(id -u $MOUNTUSER) -o gid=$(id -g $MOUNTUSER) $VMUSER@$IP:/home/$VMUSER/$VMFOLDER $MOUNTPOINT/$1 -o IdentityFile=$IDENTITYFILE"
    sshfs -o allow_other -o uid=$(id -u $MOUNTUSER) -o gid=$(id -g $MOUNTUSER) $VMUSER@$IP:/home/$VMUSER/$VMFOLDER $MOUNTPOINT/$1 -o IdentityFile=$IDENTITYFILE
    exit
fi


# Use samba method
if [ "$(is_samba $1)" == "True" ] && [ "$(check_key $1)" == "True" ]; then

    MOUNTPOINT=$(get_value $1 "Mountpoint")
    MOUNTUSER=$(get_value $1 "MountUser")
    VMUSER=$(get_value $1 "VMUser")
    VMFOLDER=$(get_value $1 "VMFolder")
    IP=$(get_value $1 "HostName")
    PASSWORD=$(get_value $1 "SambaPassword")


    if grep -qsw "$MOUNTPOINT/$1" "/proc/mounts"; then
        echo -e "$LRED[-] Location $MOUNTPOINT/$1 already mounted$NC"
        exit
    fi

    if [ ! -d  "$MOUNTPOINT/$1" ]; then
        mkdir $MOUNTPOINT/$1
        chown -R $MOUNTUSER: $MOUNTPOINT/$1
    fi
    echo "[*] mount.cifs "//$IP/$VMFOLDER" "$MOUNTPOINT/$1" -o user=$VMUSER,pass=$PASSWORD,uid=$(id -u $MOUNTUSER),gid=$(id -g $MOUNTUSER)"
    mount.cifs "//$IP/$VMFOLDER" "$MOUNTPOINT/$1" -o user=$VMUSER,pass=$PASSWORD,uid=$(id -u $MOUNTUSER),gid=$(id -g $MOUNTUSER)


else
    help
fi


