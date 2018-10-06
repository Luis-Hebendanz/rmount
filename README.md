# rmount


## Short Description
Remote mount utility which parses a json file. Like the ssh_config for ssh just for sshfs and samba.
Primarily developed to network-mount Windows and Linux Virtual Machines to local machine. 

## Technical Description
The rmount utility will search for a file called 'config.json' in the executing directory. 
It is recommended to add this bash script as alias. The moment it gets executed rmount searches in your current directory where the config.json is.
Then it parses the file. The script tries first to search for every key in it's designated Host struct. If it does not find the key there it searches for the same key in "Default".

The rmount utility can also scan the network and enumerate possible samba and ssh servers. For this to happen use
```
./rmount.bash scan <option> <network-range>
 Options:
 ssh samba
```

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

## Help display
```
./rmount.bash <name>
Names:
ubuntu14vm win7vm

./rmount.bash scan <option> <network-range>
 Options:
 ssh samba
 ```

## Example execution
* Mount the host 
user@192.168.122.140:/home/user/Share to /home/linus/Share/ubuntu14vm
```
./rmount.bash ubuntu14vm
```

* Scan for samba servers
```
./rmount.bash scan samba 192.168.122.0/24
```

## Share folder under Windows
[Click Here](https://www.howtogeek.com/176471/how-to-share-files-between-windows-and-linux/)


