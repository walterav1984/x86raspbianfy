#!/bin/bash
#
# host.sh 'architecure' 'imgsize in megabytes numbers'
#
#Its pretty obvious what happens here, but it installs qemu, downloads an iso 
#creates a 1GB diskimage for the virtualmachine starts the virtualmachine with
#telnet capabilities and let 'host2guest.sh' feed/automate the whole process.

#first argument determines architecture
IARCH=$1

QARCH=$(case $1 in
i386)
echo "i386"
;;
amd64)
echo "x86_64"
;;
esac
)

#second argument determines img size
DSIZE=$2
echo $DSIZE
ISIZE=$(($DSIZE - 50))
echo $ISIZE

#telnetport based on architecture allows i386/amd64 img creation at same time
TPORT=$(case $1 in
i386)
echo "32"
;;
amd64)
echo "64"
;;
esac
)

sudo apt-get update
sudo apt-get -y install qemu-kvm
wget https://caesar.ftp.acc.umu.se/debian-cd/current/$IARCH/iso-cd/debian-9.5.0-$IARCH-netinst.iso
qemu-img create -f raw disk-$IARCH-$DSIZE.img $ISIZE'M'
sudo qemu-system-$QARCH -enable-kvm -drive format=raw,file=disk-$IARCH-$DSIZE.img -cdrom debian-9.5.0-$IARCH-netinst.iso -boot d -m 512 -monitor telnet:localhost:93$TPORT,server,nowait &
sleep 10
./host2guest.sh qcmpayload.txt $TPORT $IARCH
