#!/bin/bash
#
# host.sh
#
#Its pretty obvious what happens here, but it installs qemu, downloads an iso 
#creates a 1GB diskimage for the virtualmachine starts the virtualmachine with
#telnet capabilities and let 'host2guest.sh' feed/automate the whole process.
 
sudo apt-get update
sudo apt-get -y install qemu-kvm
wget https://caesar.ftp.acc.umu.se/debian-cd/current/i386/iso-cd/debian-9.5.0-i386-netinst.iso
#wget https://caesar.ftp.acc.umu.se/debian-cd/current/amd64/iso-cd/debian-9.5.0-amd64-netinst.iso
qemu-img create -f raw disk1GB.img 953M
sudo qemu-system-i386 -enable-kvm -cpu host,-pae -drive format=raw,file=disk1GB.img -cdrom debian-9.5.0-i386-netinst.iso -boot d -m 512 -monitor telnet:localhost:9312,server,nowait &
sleep 10
./host2guest.sh qcmpayload.txt
