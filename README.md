# rmount

## Description
Remote mount utility which parses a json file. Like the ssh_config for ssh just for sshfs and samba.
Primarily developed to network-mount Windows and Linux Virtual Machines to local machine. 

## Audience
Qemu/KVM users who want a painless way to have file sharing with its Windows and Linux hosts.

## Dependencies
sudo apt install nmap jq cifs-utils sshfs

## Execute mounting
```
./rmount.bash <name>

./rmount.bash scan <option> <network-range>
 Options:
 ssh samba
 ```


