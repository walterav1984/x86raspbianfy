#!/bin/bash
#
# rf.sh (x86raspbianfy)
#
#This script mimics a debian i686/amd64 system with 2primary mbr ext4 partitions
#'/boot' and '/' into a raspbian-lite configurable image as in reformatted /boot 
#partition in accessible FAT filesystem configurable with raspberry like text-
#files for instance 'wpa_supplicant.conf' or 'ssh' and similar shipped packages.

WHICHDISTRO=$(cat /etc/issue | sed "s| .*||" | sed -e 's/\(.*\)/\L\1/' | egrep "debian|ubuntu")
WHICHRELEASE=$(cat /etc/apt/sources.list | grep -E "debian|ubuntu" | head -n 1 | sed "s|.*$WHICHDISTRO/ ||" | sed "s| main.*||")
ENCRYPTED=$(sudo blkid | grep crypto | sed -e "s|.*crypto|crypto|" | sed -e "s|_LUKS.*||")

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
sudo cp /etc/fstab /etc/fstab.bak
case $ENCRYPTED in
crypto)
head -n 9 /etc/fstab | sudo tee /etc/fstab
;;
*)
head /etc/fstab | sudo tee /etc/fstab
;;
esac
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
sudo sed -i 's/GRUB_TIMEOUT_STYLE=hidden/#GRUB_TIMEOUT_STYLE=hidden/g' /etc/default/grub
sudo sed -i 's/GRUB_TIMEOUT=0/GRUB_TIMEOUT=5/g' /etc/default/grub
sudo sed -i 's/GRUB_HIDDEN_TIMEOUT=0/#GRUB_HIDDEN_TIMEOUT=0/g' /etc/default/grub
sudo sed -i 's/=console/="console serial"/g' /etc/default/grub #intel nuc won't boot if monitor is disconnected unless 'console' gets removed!
sudo sed -i 's/#GRUB_TERMINAL/GRUB_TERMINAL/g' /etc/default/grub
sudo sed -i 's/""/"console=ttyS0,115200 console=tty1 net.ifnames=0 biosdevname=0 init_on_alloc=0 #vmalloc=128M noefi vga=normal video=vesafb:off nofb nomodeset modprobe.blacklist=gma500_gfx i915.modeset=0 nouveau.modeset=0 mitigations=off fsck.mode=skip nopersistent"/g' /etc/default/grub
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
sudo grub-install --efi-directory=/boot/ --boot-directory=/boot/gre3 /dev/sda --target=i386-efi --removable #--no-nvram
sudo grub-mkconfig -o /boot/gre3/grub/grub.cfg #is the same as bios version
#mkdir /boot/EFI/BOOT
#cp /boot/EFI/*b*/grubia32.efi /boot/EFI/BOOT/BOOTIA32.efi
sudo rm -r /var/archives/grub-efi*
}

function grub2uefi64 {
sudo apt-get -y install -d -o=dir::cache=/var grub-efi-amd64
sudo chmod -R 777 /var/archives
dpkg -x /var/archives/grub-efi-amd64_*.deb /var/archives/grub-efi-amd64
dpkg -x /var/archives/grub-efi-amd64-bin*.deb /var/archives/grub-efi-amd64-bin
sudo cp -a '/var/archives/grub-efi-amd64-bin/usr/lib/grub/x86_64-efi' /usr/lib/grub/
sudo grub-install --efi-directory=/boot/ --boot-directory=/boot/gre6 /dev/sda --target=x86_64-efi --removable #--no-nvram
sudo grub-mkconfig -o /boot/gre6/grub/grub.cfg #is the same as bios version
#mkdir /boot/EFI/BOOT
#cp /boot/EFI/*b*/grubx64.efi /boot/EFI/BOOT/BOOTX64.efi
sudo rm -r /var/archives/grub-efi*
}

function grubahcisata {
sudo tee -a /etc/grub.d/40_custom <<EOF
set -e

# Uncomment line corresponding your chipset to force sata AHCI mode!
# Use 'lspci' to detect specific chipset id!

# Nvidia MCP79
#echo "setpci -d 10de:0ab5 9c.b=06"

# Intel ICH6/631xESB/632xESB
#echo "setpci -d 8086:2680 90.b=40"

# Intel ICH7
#echo "setpci -s 00:1f.2 90.b=40"
EOF
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
case $WHICHDISTRO in
debian)
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
;;
ubuntu)
sudo tee /etc/rc.local <<EOF
#!/bin/sh -e
#
# rc.local
#

exit 0
EOF
sudo chmod +x /etc/rc.local
;;
esac
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

function postinstallscripts {
sudo apt-get -y install parted mtools blktool --no-install-recommends
cat <<'EOF' > /home/pi/init_resize_rootfs.sh
#!/bin/bash

ROOTUUID=$(cat /etc/fstab | grep vfat | grep -v "#" |sed -e 's| /.*|"|' | sed 's|=|="|' )

SIZEDISK=$(sudo blkid | grep $ROOTUUID | sed -e  's|1:.*||')
SIZEPART=$(sudo blkid | grep $ROOTUUID | sed -e  's|1:.*|2|')

sync
echo "Check if the disk and partition below are the correct ones to resize?"
echo $SIZEDISK $SIZEPART
echo "Than run this script with sudo in case it says command not found!"
EOF
case $WHICHRELEASE in
focal)
cat <<'EOF' >> /home/pi/init_resize_rootfs.sh
echo -e "yes\n100%" | sudo parted $SIZEDISK ---pretend-input-tty unit % resizepart 2
EOF
;;
buster)
cat <<'EOF' >> /home/pi/init_resize_rootfs.sh
echo -e "100%\nyes" | sudo parted $SIZEDISK ---pretend-input-tty unit % resizepart 2
EOF
;;
*)
cat <<'EOF' >> /home/pi/init_resize_rootfs.sh
parted $SIZEDISK resizepart 2 y 100% #v3.2 buster swapped y / v3.3 focal won't script bug/bydesign 
EOF
;;
esac
case $ENCRYPTED in
crypto)
case $WHICHRELEASE in
focal)
cat <<'EOF' >> /home/pi/init_resize_rootfs.sh
echo -e "yes\n100%" | sudo parted $SIZEDISK ---pretend-input-tty unit % resizepart 5
EOF
;;
buster)
cat <<'EOF' >> /home/pi/init_resize_rootfs.sh
echo -e "100%\nyes" | sudo parted $SIZEDISK ---pretend-input-tty unit % resizepart 5
EOF
;;
*)
cat <<'EOF' >> /home/pi/init_resize_rootfs.sh
parted $SIZEDISK resizepart 5 y 100% #v3.2 buster swapped y / v3.3 focal won't script bug/bydesign 
EOF
;;
esac
cat <<'EOF' >> /home/pi/init_resize_rootfs.sh
printf "raspberry"|sudo cryptsetup resize sda5_crypt #password!
sudo pvresize /dev/mapper/sda5_crypt
sudo lvextend -l +100%FREE /dev/lvmgrp/lvmv1 #lvresize also works
sudo resize2fs -p /dev/mapper/lvmgrp-lvmv1
sync
reboot
EOF
;;
*)
cat <<'EOF' >> /home/pi/init_resize_rootfs.sh
sync
resize2fs $SIZEPART
sync
reboot
EOF
;;
esac

chmod +x /home/pi/init_resize_rootfs.sh

cat <<'EOF' > /home/pi/init_change_uuids.sh
#!/bin/bash

#only works on Ubuntu 16.04 or lower? Debian 9 needs metadata_csum_seed but grub-probe won't detect UUID after change?

WHICHDR=$(cat /etc/issue | sed "s|[^0-9]*||g")

case $WHICHDR in
8)
T2FSOPT=""
;;
16045)
T2FSOPT=""
;;
*)
T2FSOPT="metadata_csum_seed,"
;;
esac

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
sudo tune2fs -O $T2FSOPT^uninit_bg $RDEVPART
#sudo tune2fs -U $uuid $root_disk
sudo tune2fs $RDEVPART -U random
sudo tune2fs -O $T2FSOPT+uninit_bg $RDEVPART
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

cat <<'EOF' > /home/pi/init_boot2root_uefibios_grubfix.sh
#!/bin/bash

#
# init_boot2root_uefibios_grubfix.sh 
#

#detect bios/uefi-type kernel 3.16/4.x or higher
if [ -d /sys/firmware/efi ];then
EFITYPE=$(cat /sys/firmware/efi/fw_platform_size)
 case $EFITYPE in
 32)
 BOOTFIRMWARE=ia32
 ;;
 64)
 BOOTFIRMWARE=amd64
 ;;
 esac
else
 BOOTFIRMWARE=BIOS
fi

ORIBUUID=$(cat /etc/fstab | grep vfat | sed 's|/.*||' | sed 's|.*=||')
ORIRUUID=$(cat /etc/fstab | grep ext4 | sed 's|/.*||' | sed 's|.*=||')
WHICHSTORAGETYPE=$(sudo blkid | grep $ORIRUUID | sed 's|/dev/||' | cut -c 1-2)

case $WHICHSTORAGETYPE in
sd)
BRDEV=$(sudo blkid | grep $ORIRUUID | sed 's|:.*||'| sed 's|[0-9]||g')
#sda2
;;
hd)
BRDEV=$(sudo blkid | grep $ORIRUUID | sed 's|:.*||'| sed 's|[0-9]||g')
#hda2
;;
nv)
BRDEV=$(sudo blkid | grep $ORIRUUID | sed 's|:.*||'| sed 's|p[0-9]*||g')
#nvme0n1p2
;;
mm)
BRDEV=$(sudo blkid | grep $ORIRUUID | sed 's|:.*||'| sed 's|p[0-9]*||g')
#mmcblk0p2
;;
esac

BDEVPART=$(sudo blkid | grep $ORIBUUID | sed 's|:.*||')
RDEVPART=$(sudo blkid | grep $ORIRUUID | sed 's|:.*||')

function boot2root {
#remove /boot symlinks...
sudo unlink /etc/default/keyboard
sudo unlink /etc/dhcpcd.conf
sudo unlink /etc/wpa_supplicant/wpa_supplicant.conf
#move boot partition to /boot
cd /
sudo cp -a /boot /boot.bak
sudo rm -r /boot/*
echo "The x86raspbianfy boot partition options have moved to root /boot to make it compatible with native Debian OS update/upgrade!" | sudo tee /boot/readme.txt
sudo umount /boot

cd /boot.bak
sudo cp -a * /boot/
#restore /boot symlinks...
sudo ln -s /boot/keyboard /etc/default/keyboard
sudo chown root:netdev /boot/dhcpcd.conf
sudo ln -s /boot/dhcpcd.conf /etc/dhcpcd.conf
sudo ln -s /boot/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf
head -n 9 /etc/fstab | sudo tee /etc/fstab
}

#TODO native Mac System Preferences Startup Disk Pane support gives blackscreen...
#https://glandium.org/blog/?p=2830
#https://discussions.apple.com/thread/1677851
#https://www.insanelymac.com/forum/topic/12299-could-someone-clear-a-few-things-up-for-me/
#needs GPT and needs HFS #Journaled?ignore permissions?
#could not set boot device property: 0xe00002bc #csrutil status el capitan >?
#sudo apt -y install hfsprogs gdisk #mbr icnsutils wget librsvg2-bin build-essential 
#sudo cp -a /boot /boot.bak
#sudo umount /boot
#printf "a\n1\nt\n1\naf\nw\nq\n" sudo fdisk /dev/sdx #disables mbr boot flag p1 changes fat to hfs 
#sudo mkfs.hfsplus /dev/sdb1 -v Debian
#sudo cp -a /boot.bak /boot
#sudo mv /boot/EFI /boot/tefi
#sudo mkdir /boot/efi
#fstab/mount hfsplus /boot/efi
#printf "w\ny\n" | sudo gdisk /dev/sdb #99% resize gpt needs space at disk end!!
#sudo grub-install /dev/sdb --target=x86_64-efi --removable 
#error ... not found core.efi part_gpt.mod ext2.mod fshelp.mod hfsmod?
#it creates /boot/efi/EFI/BOOT/S*/L*/CoreS*/ wrong folder
#manually move  /S*/L*/CoreS*/
#add fake kernel /mach_kernel /S/L/Kernels/kernel
#add info plist
#wget http://www.codon.org.uk/~mjg59/mactel-boot/mactel-boot-0.9.tar.bz2
#tar -jxf mactel-boot-0.9.tar.bz2
#cd mactel-boot-0.9
#make PRODUCTVERSION=DebianB
#cp SystemVersion.plist /mnt/System/Library/CoreServices/
#bless?
#wget https://debian.org/logos/openlogo.svg
#rsvg-convert -w 128 -h 128 -o /tmp/debian.png openlogo.svg
#sudo png2icns /mnt/.VolumeIcon.icns /tmp/debian.png
#gdisk  hybrid mbr?
#sudo gdisk /dev/sda #printf "x\nr\nh\n1 2\nn\n\nn\ny\nw\ny\n" 100% resize don't 99%!
#sudo grub-install /dev/sdb2 --boot-directory=/boot --force
#sudo fdisk /dev/sdb #a1 a2 w set partpart 1>2 printf "a\n1\na\n2\nw\nq\n"
#sudo install-mbr -p 2 /dev/sda
#bless -device /dev/disk0s3 -legacy -setBoot -nextonly* usb?

function boot2efi {
#alter vfat boot partition id to EFI partition hides Finder MacOS and unbootable
#printf "t\n1\nef\nw\nq\n" | sudo fdisk $BRDEV #partition id EFI
sudo mv /boot/EFI /boot/tefi
sudo mkdir /boot/efi
BDEVUUID=$(sudo blkid | grep $BDEVPART | sed "s|.* UUID|UUID|" | sed "s| TYPE.*||" | sed 's|"||g')
echo "$BDEVUUID /boot/efi vfat umask=0077 0 1" | sudo tee -a /etc/fstab
sudo mount -a
#mount /dev/sda1 /boot/efi
}

case $BOOTFIRMWARE in
BIOS)
boot2root
sudo grub-install $BRDEV
sudo update-grub2
;;
ia32)
boot2root
boot2efi
#sudo apt-get -y install grub-efi-ia32 #grub-efi-ia32-bin efibootmgr / nvram?
sudo grub-install --target=i386-efi $BRDEV --removable
sudo grub-install $BRDEV
sudo update-grub2
#sudo efibootmgr -v
;;
amd64)
boot2root
boot2efi
#sudo apt-get -y install grub-efi-amd64 #grub-efi-ia32-bin efibootmgr / nvram?
sudo grub-install --target=x86_64-efi $BRDEV --removable
sudo grub-install $BRDEV
sudo update-grub2
#sudo efibootmgr -v
#sudo grub-install --efi-directory=/boot/efi/EFI? --boot-directory=/boot /dev/sda --target= --no-nvram #--removable = --no-nvram = /efi/boot/bootx.efi files
;;
esac
#sudo apt remove / dpkg-reconfigure grub-pc
echo "sudo efibootmgr -v #check if efi nvram variable for debian/ubuntu was set"
echo ""
echo "                             Apple Mac's                                 "
echo ""
echo "On Apple Mac's use bootpicker during poweron by holding the 'Option' Key"
echo "it shows 'EFI BOOT' option which boots the system into 'x86raspbianfy'."
echo "This will work for both 32/64 EFI Mac's, however if you have replaced the"
echo "GPU on a MacPro and have no bootscreen, you have to start MacOS first and"
echo "have disabled System Integrity Protection with csrutil or T2 systems even"
echo "have /Applications/Utilities/Startup Security Utilitiy to be cleared."
echo "From the Terminal in MacOS this bless command will boot debian once and"
echo "after restarting debian it will boot back to the default MacOS again."
echo "sudo bless --mount /Volumes/boot --file /Volumes/boot/EFI/BOOT/BOOTXYZ.efi --setBoot --nextonly" 
echo "You have to replace 'BOOTXYZ.efi' corresponding to your EFI architecture"
echo "for 32bit efi use 'BOOTIA32.efi' and 64bit efi use 'BOOTX64.efi' than to"
exit "boot x86raspbianfy restart your Mac from 'Apple menu' > 'Restart' option."
EOF
chmod +x /home/pi/init_boot2root_uefibios_grubfix.sh
}

function removeswap {
#ubuntu 18.04 mini install comes with a swapfile...
sudo swapoff -a
sudo rm /swapfile
sudo sed -i 's|/swapfile|#/swapfile|' /etc/fstab
}

function fixrecoverymode {
echo "root:raspberry" | sudo chpasswd
sudo apt-get -y remove friendly-recovery
}

function x86raspbianrepo {
sudo apt-get -y install gnupg2
echo "deb http://archive.raspberrypi.org/debian/ $WHICHRELEASE main ui" | sudo tee /etc/apt/sources.list.d/raspi.list
curl http://archive.raspberrypi.org/debian/raspberrypi.gpg.key -o /tmp/rrkey
sudo cat /tmp/rrkey | sudo apt-key add -
sudo apt-get update
}

function raspbianliteslim {
case $WHICHDISTRO in
debian)
DEBIANONLY="firmware-atheros firmware-brcm80211 firmware-libertas firmware-misc-nonfree firmware-realtek" #blends-tasks
;;
ubuntu)
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
debian)
case $WHICHRELEASE in
jessie)
echo "TODO:test if jessie-backports is new enough?"
;;
stretch)
echo "deb http://ftp.debian.org/debian stretch-backports main non-free contrib" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade #otherwise kernel-headers will not be build for current new kernel
sudo apt-get -y install dpkg-dev linux-headers-$HEADERS #backport installs headers for backport kernel?
sudo apt-get -y install -t stretch-backports virtualbox-guest-dkms #installs headers new kernel?
sudo poweroff;exit
;;
buster)
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade #otherwise kernel-headers will not be build for current new kernel
sudo apt-get -y install dpkg-dev linux-headers-$HEADERS #backport installs headers for backport kernel?
sudo apt-get -y install virtualbox-guest-dkms #installs headers new kernel?
sudo poweroff;exit
;;
esac
;;
ubuntu)
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
x86raspbianrepo
raspbianliteslim
postinstallscripts
x86tools
personal
fixrecoverymode
dhcpcdconfig
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
mkrclocal
mksshswitch
cmdlinetxt
keyboardlang
raspbianliteslim
postinstallscripts
x86tools
personal
fixrecoverymode
dhcpcdconfig
}

function make1 {
case $WHICHDISTRO in
debian)
debian
;;
ubuntu)
ubuntu
;;
esac
}

function make2 {
case $WHICHDISTRO in
debian)
debian
raspbianlitefull
;;
ubuntu)
ubuntu
#raspbianlitefull
;;
esac
}

$PERFORM

#sudo poweroff;exit
echo "All Done, gracefully shutdown vmguest 'sudo systemctl poweroff;exit' to use image"
exit 0
