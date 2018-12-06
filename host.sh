#!/bin/bash
#
# host.sh 'action' 'distro' 'codename' 'architecture' 'imgsize in gigabytes numbers'
#
#Its pretty obvious what happens here, it installs qemu, downloads an iso 
#creates a xGB diskimage for the virtualmachine starts the virtualmachine with
#telnet capabilities and let 'host2guest.sh' feed/automate the whole process.

sudo echo "Figure out how to give current user elevated rights for qemu-kvm or keep using sudo..."

#first argument defines action "prepare/create/modify/convertovb"
XACT=$1

#second argument defines distro
DISTRO=$2

#third argument defines codename/release
CNAME=$3

#fouth argument defines architecture
IARCH=$4

#fifth argument defines fixed img size of 1GB / 2GB
#2gb or larger installs default utils during install and raspbian-litefull vs slim package selection?
#2gb larger boot volume
DSIZE=$5
#echo 50MB smaller?
case $DSIZE in
1GB)
ISIZE=976
;;
2GB)
ISIZE=1950
;;
esac

#telnetport based on architecture allows i386/amd64 img creation at same time
TPORT=$(case $IARCH in
i386)
echo "9332"
;;
amd64)
echo "9364"
;;
esac
)

#arch dependent variables
case $IARCH in
i386)
QARCH="i386"
OVBARCH=""
;;
amd64)
QARCH="x86_64"
OVBARCH="_64"
;;
esac

#distro&arch dependent variables
case $DISTRO in
debian)
    case $CNAME in
        jessie)
        QCMPAYLOAD=qcmpayloadd8.txt
        ;;
        stretch)
        QCMPAYLOAD=qcmpayloadd9.txt
        ;;
    esac
OVBOSTYPE="Debian$OVBARCH"
;;
ubuntu)
    case $CNAME in
        xenial)
        QCMPAYLOAD=qcmpayloadu1604.txt
        ;;
        bionic)
        QCMPAYLOAD=qcmpayloadu1804.txt
        ;;
    esac
OVBOSTYPE="Ubuntu$OVBARCH"
;;
esac

DISO="isos/$DISTRO-$CNAME-$IARCH.iso"

function prepare {
sudo apt-get update
sudo apt-get -y install qemu-kvm virtualbox virtualbox-guest-additions-iso
mkdir isos
cd isos
DISTRO=debian
IARCH=i386
wget https://cdimage.debian.org/cdimage/archive/8.11.0/$IARCH/iso-cd/debian-8.11.0-$IARCH-netinst.iso -O $DISTRO-jessie-$IARCH.iso
IARCH=amd64
wget https://cdimage.debian.org/cdimage/archive/8.11.0/$IARCH/iso-cd/debian-8.11.0-$IARCH-netinst.iso -O $DISTRO-jessie-$IARCH.iso
IARCH=i386
wget https://cdimage.debian.org/cdimage/archive/9.5.0/$IARCH/iso-cd/debian-9.5.0-$IARCH-netinst.iso -O $DISTRO-stretch-$IARCH.iso
IARCH=amd64
wget https://cdimage.debian.org/cdimage/archive/9.5.0/$IARCH/iso-cd/debian-9.5.0-$IARCH-netinst.iso -O $DISTRO-stretch-$IARCH.iso
DISTRO=ubuntu
IARCH=i386
wget http://archive.ubuntu.com/ubuntu/dists/xenial/main/installer-$IARCH/current/images/netboot/mini.iso -O $DISTRO-xenial-$IARCH.iso
IARCH=amd64
wget http://archive.ubuntu.com/ubuntu/dists/xenial/main/installer-$IARCH/current/images/netboot/mini.iso -O $DISTRO-xenial-$IARCH.iso
IARCH=i386
wget http://archive.ubuntu.com/ubuntu/dists/bionic/main/installer-$IARCH/current/images/netboot/mini.iso -O $DISTRO-bionic-$IARCH.iso
IARCH=amd64
wget http://archive.ubuntu.com/ubuntu/dists/bionic/main/installer-$IARCH/current/images/netboot/mini.iso -O $DISTRO-bionic-$IARCH.iso
cd ..
}

function create {
#create system
qemu-img create -f raw disk-$DISTRO-$CNAME-$IARCH-$DSIZE.img $ISIZE'M'
sudo qemu-system-$QARCH -enable-kvm -drive format=raw,file=disk-$DISTRO-$CNAME-$IARCH-$DSIZE.img -cdrom $DISO -boot d -m 512 -monitor telnet:localhost:$TPORT,server,nowait & #-device usb-ehci,id=ehci -device usb-host,id=asix,bus=ehci.0,vendorid=0x0b95,productid=0x7720 &
sleep 10
./host2guest.sh $QCMPAYLOAD $TPORT $IARCH $DSIZE 
}

function modify {
#boot current image
sudo qemu-system-$QARCH -enable-kvm -drive format=raw,file=disk-$DISTRO-$CNAME-$IARCH-$DSIZE.img -cdrom $DISO -boot c -m 512 -monitor telnet:localhost:$TPORT,server,nowait & #-device usb-ehci,id=ehci -device usb-host,id=asix,bus=ehci.0,vendorid=0x0b95,productid=0x7720 &
}

function convertovb {
#install target guestadditions
QCMPAYLOAD=qcmpayload-covb.txt
sudo qemu-system-$QARCH -enable-kvm -drive format=raw,file=disk-$DISTRO-$CNAME-$IARCH-$DSIZE.img -cdrom $DISO -boot c -m 512 -monitor telnet:localhost:$TPORT,server,nowait & #-device usb-ehci,id=ehci -device usb-host,id=asix,bus=ehci.0,vendorid=0x0b95,productid=0x7720 &
sleep 10
./host2guest.sh $QCMPAYLOAD $TPORT $IARCH
#sleep wait or continue after host2guest finish? 

#convert current image to vbox appliance
#VirtualBox VM NAME
OVMN=$DISTRO-$CNAME-$IARCH-$DSIZE
VBoxManage convertfromraw disk-$DISTRO-$CNAME-$IARCH-$DSIZE.img --format vdi $OVMN.vdi
#modifymedium vdi --resize mb ?
#modifyhds ?
VBoxManage createvm --name $OVMN --ostype "$OVBOSTYPE" --register #32bit/Debian_64 #VBoxManage list ostypes
VBoxManage storagectl $OVMN --name "SATA Controller" --add sata --controller IntelAHCI
VBoxManage storageattach $OVMN --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $OVMN.vdi
VBoxManage modifyvm $OVMN --memory 512 #default 128/512 ok
VBoxManage modifyvm $OVMN --nic2 bridged --bridgeadapter2 enp1s0 #/ e1000g0 dhcp mac? --macaddress
#VBoxManage modifyvm $OVMN --macaddress2 AABBCCDDEEFF
VBoxManage export $OVMN -o $OVMN-vbox-appliance.ova
#VBoxManage unregistervm $OVMN --delete
}

$XACT

exit 0
