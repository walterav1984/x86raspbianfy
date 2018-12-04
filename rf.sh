#!/bin/bash
#
# rf.sh (x86raspbianfy)
#
#This script mimics a debian i686/amd64 system with 2primary mbr ext4 partitions
#'/boot' and '/' into a raspbian-lite configurable image as in reformatted /boot 
#partition in accessible FAT filesystem configurable with raspberry like text-
#files for instance 'wpa_supplicant.conf' or 'ssh' and similar shipped packages.

WHICHDISTRO=$(cat /etc/issue | sed "s| .*||" | egrep "Debian|Ubuntu")

PERFORM=$1

function fixsudo {
echo "pi ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
sudo sed -i "s/%sudo/#%sudo/g" /etc/sudoers
}

function decswap {
echo "vm.swappiness=1" | sudo tee -a /etc/sysctl.conf
}

function bootfat {
sudo apt-get -y install dosfstools
cd /
sudo cp -a boot boot.bak
sudo umount /boot
head /etc/fstab | sudo tee /etc/fstab
sudo sed -i "s/errors=remount-ro/defaults,noatime/g" /etc/fstab
sudo mkfs.msdos -n boot /dev/sda1
printf "t\n1\nc\nw\nq\n" | sudo fdisk /dev/sda
sleep 5
sync
SDA1UUID=$(sudo blkid | grep sda1 | sed "s|.* UUID|UUID|" | sed "s| TYPE.*||" | sed 's|"||g')
echo "$SDA1UUID /boot vfat defaults 0 2" | sudo tee -a /etc/fstab
sudo mount -a
cd /boot.bak
sudo cp -a * /boot/
sudo grub-install /dev/sda --boot-directory=/boot
sudo update-grub2
sudo rm -r /boot.bak
sudo sed -i "s/do_symlinks = yes/do_symlinks = no/g" /etc/kernel-img.conf
}

function grub2defaults {
sudo sed -i 's/GRUB_HIDDEN_TIMEOUT=0/#GRUB_HIDDEN_TIMEOUT=0/g' /etc/default/grub
sudo sed -i 's/=console/="console serial"/g' /etc/default/grub
sudo sed -i 's/#GRUB_TERMINAL/GRUB_TERMINAL/g' /etc/default/grub
sudo sed -i 's/""/"console=tty1 console=ttyS0,115200 net.ifnames=0 biosdevname=0 vmalloc=128M #vga=normal video=vesafb:off nofb nomodeset modprobe.blacklist=gma500_gfx i915.modeset=0 nouveau.modeset=0"/g' /etc/default/grub
sudo sed -i 's/"quiet.*/""/g' /etc/default/grub
echo 'GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' | sudo tee -a /etc/default/grub
sudo update-grub2
}

function grub2uefi32 {
sudo apt-get -y install -d -o=dir::cache=/var grub-efi-ia32
sudo chmod -R 777 /var/archives
dpkg -x /var/archives/grub-efi-ia32_*.deb /var/archives/grub-efi-ia32
dpkg -x /var/archives/grub-efi-ia32-bin*.deb /var/archives/grub-efi-ia32-bin
sudo cp -a '/var/archives/grub-efi-ia32-bin/usr/lib/grub/i386-efi' /usr/lib/grub/
sudo grub-install --efi-directory=/boot/ --boot-directory=/boot/gre3 /dev/sda --target=i386-efi --no-nvram
sudo grub-mkconfig -o /boot/gre3/grub/grub.cfg #is the same as bios version
mkdir /boot/EFI/BOOT
cp /boot/EFI/*b*/grubia32.efi /boot/EFI/BOOT/BOOTIA32.efi
sudo rm -r /var/archives/grub-efi*
}

function grub2uefi64 {
sudo apt-get -y install -d -o=dir::cache=/var grub-efi-amd64
sudo chmod -R 777 /var/archives
dpkg -x /var/archives/grub-efi-amd64_*.deb /var/archives/grub-efi-amd64
dpkg -x /var/archives/grub-efi-amd64-bin*.deb /var/archives/grub-efi-amd64-bin
sudo cp -a '/var/archives/grub-efi-amd64-bin/usr/lib/grub/x86_64-efi' /usr/lib/grub/
sudo grub-install --efi-directory=/boot/ --boot-directory=/boot/gre6 /dev/sda --target=x86_64-efi --no-nvram
sudo grub-mkconfig -o /boot/gre6/grub/grub.cfg #is the same as bios version
mkdir /boot/EFI/BOOT
cp /boot/EFI/*b*/grubx64.efi /boot/EFI/BOOT/BOOTX64.efi
sudo rm -r /var/archives/grub-efi*
}

function autonetconf {
sudo apt-get -y install crda dhcpcd5 ethtool net-tools wireless-tools wireless-regdb wpasupplicant
sudo ln -s /usr/share/dhcpcd/hooks/10-wpa_supplicant /lib/dhcpcd/dhcpcd-hooks/10-wpa_supplicant
sudo systemctl disable wpa_supplicant.service
head -n3 /etc/network/interfaces | sudo tee /etc/network/interfaces
echo "source-directory /etc/network/interfaced.d" | sudo tee -a /etc/network/interfaces
sudo touch /boot/wpa_supplicant.conf
sudo tee /boot/wpa_supplicant.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=UK

network={
	ssid="example"
	psk="example"
	key_mgmt=WPA-PSK
}

EOF

sudo ln -s /boot/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf
}

function mksshswitch {
sudo apt-get -y install openssh-server
sudo systemctl disable ssh.service
sudo tee /etc/systemd/system/sshswitch.service <<EOF
[Unit]
Description=Turn on SSH if /boot/ssh is present
ConditionPathExistsGlob=/boot/ssh{,.txt}
#After=regenerate_ssh_host_keys.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c "systemctl start ssh.service"

[Install]
WantedBy=multi-user.target
EOF
sudo chmod +x /etc/systemd/system/sshswitch.service
sudo systemctl enable sshswitch.service
}

function mkrclocal {
sudo tee /etc/systemd/system/rc-local.service <<EOF
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOF
sudo chmod +x /etc/systemd/system/rc-local.service
sudo tee /etc/rc.local <<EOF
#!/bin/sh -e
#
# rc.local
#

exit 0
EOF
sudo chmod +x /etc/rc.local
sudo systemctl enable rc-local.service
}

function cmdlinetxt {
sudo tee /boot/cmdline.txt <<EOF
# This file does nothing on x86 you probably wan't to edit (boot)/grub/grub.cfg 
# for temp.editing kernel boot time parameters on the fly. Although these edits
# will be overwritten by system updates so permanent edits need to be done at
# /etc/default/grub and /etc/grub.d/*.
#
# https://github.com/walterav1984/x86raspbianfy
EOF
}

function keyboardlang {
sudo mv /etc/default/keyboard /boot/
sudo ln -s /boot/keyboard /etc/default/keyboard
}

function dhcpcdconfig {
sudo cp /etc/dhcpcd.conf /boot/
sudo rm /etc/dhcpcd.conf
sudo ln -s /boot/dhcpcd.conf /etc/dhcpcd.conf
}

function resizescript {
sudo apt-get -y install parted mtools blktool --no-install-recommends
cat <<'EOF' > /home/pi/init_resize_rootfs.sh
#!/bin/bash

ROOTUUID=$(cat /etc/fstab | grep ext4 | grep -v "#" |sed -e 's| /.*|"|' | sed 's|=|="|' )

SIZEDISK=$(sudo blkid | grep $ROOTUUID | sed -e  's|2:.*||')
SIZEPART=$(sudo blkid | grep $ROOTUUID | sed -e  's|:.*||')

sync
echo "Check if the disk and partition below are the correct ones to resize?"
echo $SIZEDISK $SIZEPART
echo "Than run this script with sudo in case it says command not found!"
parted $SIZEDISK resizepart 2 y 100%
sync
resize2fs $SIZEPART
sync
reboot
EOF

chmod +x /home/pi/init_resize_rootfs.sh

cat <<'EOF' > /home/pi/init_change_uuids.sh
#!/bin/bash

#only works on Ubuntu? Debian needs metadata_csum_seed incompatible grub osprober/10_linux? 
#sudo debconf-show grub-p
#sudo grub-probe --target=fs --device /dev/sdaX
#sudo blkid
#sudo mlabel -s -i /dev/sda1

ORIBUUID=$(cat /etc/fstab | grep vfat | sed 's|/.*||' | sed 's|.*=||')
ORIRUUID=$(cat /etc/fstab | grep ext4 | sed 's|/.*||' | sed 's|.*=||')
echo $ORIBUUID 
echo $ORIRUUID

BDEVPART=$(sudo blkid | grep $ORIBUUID | sed 's|:.*||')
RDEVPART=$(sudo blkid | grep $ORIRUUID | sed 's|:.*||')

echo $BDEVPART
echo $RDEVPART
#sudo tune2fs /dev/sda -U random -O metadata_csum_seed breaks grub os-prober/10-linux
sudo tune2fs -O ^uninit_bg $RDEVPART
#sudo tune2fs -U $uuid $root_disk
sudo tune2fs $RDEVPART -U random
sudo tune2fs -O +uninit_bg $RDEVPART
RREPUUID=$(sudo blkid | grep $RDEVPART | sed 's|.*" UUID="||' | sed 's|" TYPE.*| |')
echo $RREPUUID
sudo sed -i "s|$ORIRUUID|$RREPUUID|" /etc/fstab

echo mtools_skip_check=1 > /home/pi/.mtoolsrc
chown pi:pi /home/pi/.mtoolsrc
sudo cp /home/pi/.mtoolsrc /root/
sudo umount /boot
sudo mlabel -n -i $BDEVPART ::boot
BREPUUID=$(sudo blkid | grep $BDEVPART | sed 's|.*" UUID="||' | sed 's|" TYPE.*| |')
echo $BREPUUID
sudo sed -i "s|$ORIBUUID|$BREPUUID|" /etc/fstab
sudo mount /boot
sync
sudo update-grub2
EOF

chmod +x /home/pi/init_change_uuids.sh
}

function removeswap {
#ubuntu 18.04 mini install comes with a swapfile...
sudo swapoff -a
sudo rm /swapfile
sudo sed -i '|/swapfile|#/swapfile|' /etc/fstab
}

function x86raspbianrepo {
echo "deb http://archive.raspberrypi.org/debian/ stretch main ui" | sudo tee /etc/apt/sources.list.d/raspi.list
curl http://archive.raspberrypi.org/debian/raspberrypi.gpg.key -o /tmp/rrkey
sudo cat /tmp/rrkey | sudo apt-key add -
sudo apt-get update
}

function raspbianliteslim {
case $WHICHDISTRO in
Debian)
DEBIANONLY="blends-tasks firmware-atheros firmware-brcm80211 firmware-libertas firmware-misc-nonfree firmware-realtek"
;;
Ubuntu)
DEBIANONLY=""
;;
esac

sudo apt-get clean
sudo apt-get -y install alsa-utils apt-transport-https bash-completion binutils bzip2 cu dc device-tree-compiler distro-info-data ed fakeroot file hardlink htop info iw keyutils less man-db manpages ncdu netcat-openbsd netcat-traditional psmisc rsync strace unzip usb-modeswitch usbutils xml-core xz-utils $DEBIANONLY  
sudo apt-get clean
}
# "/etc/initramfs-tools/conf.d/driver-policy" MODULES=dep #forces targeted vs generic modules in init 

function raspbianlitefull {
#dphys-swapfile?
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
sudo apt-get clean
sudo apt-get autoremove
#sudo apt-get -y install ... 
#tobig apt-listchanges aptitude avahi-daemon bind9-host bluez build-essential cifs-utils cpp* dh-python gcc* g++ gdb iso-codes lsb-release nfs-common perl python samba-common
}

function x86tools {
sudo apt-get -y install pcmciautils lsscsi memtest86+ util-linux intel-microcode amd64-microcode #lm-sensors smartmontools
}

function personal {
sudo apt-get -y install vlan netcat iperf tcpdump minicom tftp lftp #dirmngr software-properties-common --no-install-recommends #nmap
}

function covb {
#virtualboxguestdkms
#remove older kernel/init to save space for updating newer/current kernel with vbox guest modules?

#check architecture
case $(uname -m) in
x86_64)
HEADERS=amd64
;;
i686)
HEADERS=686
;;
esac

#install packages depending on distro
case $WHICHDISTRO in
Debian)
echo "deb http://ftp.debian.org/debian stretch-backports main non-free contrib" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade #otherwise kernel-headers will not be build for current new kernel
sudo apt-get -y install dpkg-dev linux-headers-$HEADERS #backport installs headers for backport kernel?
sudo apt-get -y install -t stretch-backports virtualbox-guest-dkms #installs headers new kernel?
sudo poweroff;exit
;;
Ubuntu)
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
sudo apt-get -y install dpkg-dev linux-headers-generic
sudo apt-get -y install virtualbox-guest-dkms
sudo poweroff;exit
;;
esac

}

function debian {
fixsudo
decswap
bootfat
grub2defaults
grub2uefi32
grub2uefi64
autonetconf
mkrclocal
mksshswitch
cmdlinetxt
keyboardlang
dhcpcdconfig
x86raspbianrepo
raspbianliteslim
resizescript
x86tools
personal
}

function ubuntu {
removeswap
fixsudo
decswap
bootfat
grub2defaults
grub2uefi32
grub2uefi64
autonetconf
#mkrclocal
mksshswitch
cmdlinetxt
keyboardlang
dhcpcdconfig
raspbianliteslim
resizescript
x86tools
personal
}

function make1 {
case $WHICHDISTRO in
Debian)
debian
;;
Ubuntu)
ubuntu
;;
esac
}

function make2 {
case $WHICHDISTRO in
Debian)
debian
raspbianlitefull
;;
Ubuntu)
ubuntu
#raspbianlitefull
;;
esac
}

$PERFORM

#sudo poweroff;exit
echo "All Done, gracefully shutdown vmguest 'sudo poweroff;exit' to use image"
exit 0
