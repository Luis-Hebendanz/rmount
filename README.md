# rmount

## Description
Remote mount utility which parses a json file. Like the ssh_config for ssh just for sshfs and samba.
Primarily developed to network-mount Windows and Linux Virtual Machines to local machine. 

## Audience
Qemu/KVM users who want a painless way to have file sharing with its Windows and Linux hosts.

## Dependencies
sudo apt install nmap jq cifs-utils sshfs

## JSON Example
```
{
"Default": {
        "MountUser":"linus",
        "Mountpoint": "/home/linus/Share",

        "VMUser":"user",
        "VMFolder":"Share",

        "IdentityFile": "/home/linus/.ssh/id_rsa",
        "SambaPassword":"password"
        },

        "Hosts": {
                "ubuntu14vm": {
                        "Method":"ssh",
                        "HostName": "192.168.122.140"
                },

                "win7vm":{
                        "Method":"samba",
                        "HostName":"192.168.122.139"
                        }
        }
}
```


## Execute mounting
```
./rmount.bash <name>

./rmount.bash scan <option> <network-range>
 Options:
 ssh samba
 ```



