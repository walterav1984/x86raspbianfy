#!/bin/bash
#
# host.sh 'action' 'distro' 'codename' 'architecture' 'imgsize in gigabytes numbers'
#
#Its pretty obvious what happens here, it installs qemu, downloads an iso 
#creates a xGB diskimage for the virtualmachine starts the virtualmachine with
#telnet capabilities and let 'host2guest.sh' feed/automate the whole process.

#TODO
#encrypted image creation
#detect OSTYPE darwin17/debian/ubuntu?
#determin acceleration platform specific kvm/hvf
#determin package manager apt/brew

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

#amount of ram triggers low/high mem installer/question/order  OOMreaper after install? 
#384
VMRAM=448

case $DSIZE in
1GB)
ISIZE=976
;;
2GB)
ISIZE=1950
;;
4GB)
ISIZE=3764
;;
esac

#arch dependent variables
case $IARCH in
i386)
QARCH="i386"
OVBARCH=""
;;
i686)
QARCH="i386"
IARCH="i386"
OVBARCH=""
;;
amd64)
QARCH="x86_64"
OVBARCH="_64"
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

#distro&arch dependent variables
case $DISTRO in
debian)
    case $CNAME in
        jessie)
        QCMPAYLOAD=qcmpayloadd08.txt
        ;;
        stretch)
        QCMPAYLOAD=qcmpayloadd09.txt
        ;;
        buster)
        QCMPAYLOAD=qcmpayloadd10.txt
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
        disco)
        #latest i386/32bit supported installer
        QCMPAYLOAD=qcmpayloadu1904.txt
        ;;
        eoan)
        #missing i386/32bit supported installer
        QCMPAYLOAD=qcmpayloadu1910.txt
        ;;
        focal)
        #missing i386/32bit supported installer
        QCMPAYLOAD=qcmpayloadu1910.txt
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
RELNAME=jessie
RELVER=8.11.1
IARCH=i386
wget https://cdimage.debian.org/cdimage/archive/$RELVER/$IARCH/iso-cd/debian-$RELVER-$IARCH-netinst.iso -O $DISTRO-$RELNAME-$IARCH.iso
IARCH=amd64
wget https://cdimage.debian.org/cdimage/archive/$RELVER/$IARCH/iso-cd/debian-$RELVER-$IARCH-netinst.iso -O $DISTRO-$RELNAME-$IARCH.iso
RELNAME=stretch
RELVER=9.11.0
IARCH=i386
wget https://cdimage.debian.org/cdimage/archive/$RELVER/$IARCH/iso-cd/debian-$RELVER-$IARCH-netinst.iso -O $DISTRO-$RELNAME-$IARCH.iso
IARCH=amd64
wget https://cdimage.debian.org/cdimage/archive/$RELVER/$IARCH/iso-cd/debian-$RELVER-$IARCH-netinst.iso -O $DISTRO-$RELNAME-$IARCH.iso
RELNAME=buster
RELVER=10.0.0
IARCH=i386
wget https://cdimage.debian.org/cdimage/archive/$RELVER/$IARCH/iso-cd/debian-$RELVER-$IARCH-netinst.iso -O $DISTRO-$RELNAME-$IARCH.iso
IARCH=amd64
wget https://cdimage.debian.org/cdimage/archive/$RELVER/$IARCH/iso-cd/debian-$RELVER-$IARCH-netinst.iso -O $DISTRO-$RELNAME-$IARCH.iso
DISTRO=ubuntu
RELNAME=xenial
IARCH=i386
wget http://archive.ubuntu.com/ubuntu/dists/$RELNAME/main/installer-$IARCH/current/images/netboot/mini.iso -O $DISTRO-$RELNAME-$IARCH.iso
IARCH=amd64
wget http://archive.ubuntu.com/ubuntu/dists/$RELNAME/main/installer-$IARCH/current/images/netboot/mini.iso -O $DISTRO-$RELNAME-$IARCH.iso
RELNAME=bionic
IARCH=i386
wget http://archive.ubuntu.com/ubuntu/dists/$RELNAME/main/installer-$IARCH/current/images/netboot/mini.iso -O $DISTRO-$RELNAME-$IARCH.iso
IARCH=amd64
wget http://archive.ubuntu.com/ubuntu/dists/$RELNAME/main/installer-$IARCH/current/images/netboot/mini.iso -O $DISTRO-$RELNAME-$IARCH.iso
RELNAME=disco
IARCH=i386
wget http://archive.ubuntu.com/ubuntu/dists/$RELNAME/main/installer-$IARCH/current/images/netboot/mini.iso -O $DISTRO-$RELNAME-$IARCH.iso
IARCH=amd64
wget http://archive.ubuntu.com/ubuntu/dists/$RELNAME/main/installer-$IARCH/current/images/netboot/mini.iso -O $DISTRO-$RELNAME-$IARCH.iso
RELNAME=eoan
IARCH=amd64
wget http://archive.ubuntu.com/ubuntu/dists/$RELNAME/main/installer-$IARCH/current/images/netboot/mini.iso -O $DISTRO-$RELNAME-$IARCH.iso
RELNAME=focal
IARCH=amd64
wget http://archive.ubuntu.com/ubuntu/dists/$RELNAME/main/installer-$IARCH/current/images/netboot/mini.iso -O $DISTRO-$RELNAME-$IARCH.iso
cd ..
}

function create {
#create system
qemu-img create -f raw disk-$DISTRO-$CNAME-$IARCH-$DSIZE.img $ISIZE'M'
sudo qemu-system-$QARCH -accel kvm -drive format=raw,file=disk-$DISTRO-$CNAME-$IARCH-$DSIZE.img -cdrom $DISO -boot d -m $VMRAM -monitor telnet:localhost:$TPORT,server,nowait & #-device usb-ehci,id=ehci -device usb-host,id=asix,bus=ehci.0,vendorid=0x0b95,productid=0x7720 &
sleep 10
./host2guest.sh $QCMPAYLOAD $TPORT $IARCH $DSIZE 
}

function modify {
#boot current image
sudo qemu-system-$QARCH -accel kvm -drive format=raw,file=disk-$DISTRO-$CNAME-$IARCH-$DSIZE.img -cdrom $DISO -boot c -m $VMRAM -monitor telnet:localhost:$TPORT,server,nowait -device usb-ehci,id=ehci -device usb-host,id=asix,bus=ehci.0,vendorid=0x0b95,productid=0x7720 &
}

function convertovb {
#install target guestadditions
QCMPAYLOAD=qcmpayload-covb.txt
sudo qemu-system-$QARCH -accel kvm -drive format=raw,file=disk-$DISTRO-$CNAME-$IARCH-$DSIZE.img -cdrom $DISO -boot c -m $VMRAM -monitor telnet:localhost:$TPORT,server,nowait & #-device usb-ehci,id=ehci -device usb-host,id=asix,bus=ehci.0,vendorid=0x0b95,productid=0x7720 &
sleep 10
./host2guest.sh $QCMPAYLOAD $TPORT $IARCH
#sleep wait or continue after host2guest finish? 
#detect if qemu is running otherwise continue?
#NO SUDO!

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
