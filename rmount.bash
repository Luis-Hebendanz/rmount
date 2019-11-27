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
HELPNAME="rmount"

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
LRED='\033[01;31m'
LYELLOW='\033[01;33m'
NC='\033[0m' # No Color


function help()
{
    echo -e "$HELPNAME $LYELLOW<name>$NC"
    echo ""
    echo -e " Names: "
    for vm in $(jq -r ".Hosts | keys[]" "$PATHCONFIG"); do
        echo -e -n " $LYELLOW$vm$NC"
    done

    echo ""
    echo ""

    echo -e "$HELPNAME scan $LYELLOW<options>$NC <network range>"
    echo ""
    echo -e " Options:"
    echo -e "$LYELLOW ssh samba$NC"
    exit
}

# $1 --> Key
function get_default_value()
{
    local RET
    RET=$(jq -r ".Default.""$1" "$PATHCONFIG")
    echo "$RET"
}


# $1 --> Hostname-key
function check_key()
{
    local RET
    RET=$(jq -r ".Hosts.""$1" "$PATHCONFIG")

    if [ "$RET" == "null" ]; then
        echo "False"
    fi

    echo "True"
}

# $1 --> Hostname-key
function is_ssh()
{
    local RET
    RET=$(jq -r ".Hosts.""$1"".Method" "$PATHCONFIG")

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
    local RET
    RET=$(jq -r ".Hosts.""$1"".Method" "$PATHCONFIG")

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
    local RET
    RET=$(jq -r ".Hosts.""$1"".""$2" "$PATHCONFIG")
    if [ "$RET" == "null" ]; then
        local RET
        RET=$(get_default_value "$2")
        if [ "$RET" == "null" ]; then
            echo "Error in config: .Hosts.""$1"".""$2"" OR Default "
            exit
        fi
    fi
    echo "$RET"
}


# Check if script is executed as root
if [[ $EUID -ne 0 ]]; then
   echo "[-] This script must be run as root" 1>&2
   exit 1
fi


# Check if it should scan the network
if [ "$1" == "scan" ]; then

    if [ "$2" == "" ] || [ "$3" == "" ]; then
        echo -e "$HELPNAME scan$LYELLOW <option>$NC <network range>"
        echo -e "Options:$LYELLOW ssh samba$NC"
        exit
    fi

    if [ "$2" == "samba" ]; then
        echo "Scan network $3 for open samba 445 ports"
        nmap -n -p445 "$3" -oG -
        exit
    fi

    if [ "$2" == "ssh" ]; then
        echo "Scan network $3 for open ssh 22 ports"
        nmap -n -sV -p22 "$3" -oG -
        exit
    fi

    echo -e "$HELPNAME scan$LYELLOW <option>$NC <network range>"
    echo -e "Options:$LYELLOW ssh samba$NC"
    exit
fi

# Check if config file exists
if [ ! -f "$PATHCONFIG" ]; then
    echo -e "$LRED[-] Configfile '$PATHCONFIG' not found$NC"
    exit 1
fi


# Make sure config.json is owned by root
if [ "$(stat -c %U "$PATHCONFIG")" != "root" ] || [ "$(stat -c %G "$PATHCONFIG")" != "root" ]; then
    echo -e "$LRED[-] $PATHCONFIG has to be owned by user root and group root$NC"
    exit
fi

# Make sure config.json is not writeable by everyone
if [ "$(stat -c %A "$PATHCONFIG" | cut -c9)" == "w" ]; then
    echo -e "$LRED[-] $PATHCONFIG is writeable by everyone please change permissions"
    exit
fi

if [ "$1" == "" ]; then
    help
fi


# Use ssh method
if [ "$(is_ssh "$1")" == "True" ] && [ "$(check_key "$1")" == "True" ]; then

    MOUNTPOINT=$(get_value "$1" "Mountpoint")
    MOUNTUSER=$(get_value "$1" "MountUser")
    REMOTE_USER=$(get_value "$1" "RemoteUser")
    REMOTE_PATH=$(get_value "$1" "RemotePath")
    IP=$(get_value "$1" "HostName")
    IDENTITYFILE=$(get_value "$1" "IdentityFile")


    if [ "$REMOTE_PATH" == "$(basename "$REMOTE_PATH")" ]; then
        REMOTE_PATH="~/$REMOTE_PATH"
    fi

    if grep -qsw "$MOUNTPOINT/$1" "/proc/mounts"; then
        echo -e "$LRED[-] Location $MOUNTPOINT/$1 already mounted$NC"
        exit
    fi

    if [ ! -d  "$MOUNTPOINT/$1" ]; then
        mkdir "$MOUNTPOINT/$1"
        chown -R "$MOUNTUSER": "$MOUNTPOINT/$1"
    fi
    set -x
    sshfs -o allow_other -o uid="$(id -u "$MOUNTUSER")" -o gid="$(id -g "$MOUNTUSER")" "$REMOTE_USER"@"$IP":"$REMOTE_PATH" "$MOUNTPOINT"/"$1" -o IdentityFile="$IDENTITYFILE"
    set +x
    exit

fi


# Use samba method
if [ "$(is_samba "$1")" == "True" ] && [ "$(check_key "$1")" == "True" ]; then

    MOUNTPOINT=$(get_value "$1" "Mountpoint")
    MOUNTUSER=$(get_value "$1" "MountUser")
    REMOTE_USER=$(get_value "$1" "RemoteUser")
    REMOTE_PATH=$(get_value "$1" "RemotePath")
    IP=$(get_value "$1" "HostName")
    PASSWORD=$(get_value "$1" "SambaPassword")


    if grep -qsw "$MOUNTPOINT/$1" "/proc/mounts"; then
        echo -e "$LRED[-] Location $MOUNTPOINT/$1 already mounted$NC"
        exit
    fi

    if [ ! -d  "$MOUNTPOINT/$1" ]; then
        mkdir "$MOUNTPOINT/$1"
        chown -R "$MOUNTUSER:" "$MOUNTPOINT/$1"
    fi
    set -x
    mount.cifs "//$IP/$REMOTE_PATH" "$MOUNTPOINT/$1" -o user="$REMOTE_USER",pass="$PASSWORD",uid="$(id -u "$MOUNTUSER")",gid="$(id -g "$MOUNTUSER")"
    set +x


else
    help
fi


