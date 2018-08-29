#!/bin/bash
#
# rf.sh (x86raspbianfy)
#
#This script mimics a debian i686/amd64 system with 2primary mbr ext4 partitions
#'/boot' and '/' into a raspbian-lite configurable image as in reformatted /boot 
#partition in accessible FAT filesystem configurable with raspberry like text-
#files for instance 'wpa_supplicant.conf' or 'ssh' and similar shipped packages.

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
echo "/dev/sda1 /boot vfat defaults 0 2" | sudo tee -a /etc/fstab
sudo mkfs.msdos -n boot /dev/sda1
printf "t\n1\nc\nw\nq\n" | sudo fdisk /dev/sda
sleep 5
sync
sudo mount -a
cd /boot.bak
sudo cp -a * /boot/
sudo grub-install /dev/sda --boot-directory=/boot
sudo update-grub2
sudo rm -r /boot.bak
}

function grub2serial {
sudo sed -i 's/=console/="console serial"/g' /etc/default/grub
sudo sed -i 's/#GRUB_T/GRUB_T/g' /etc/default/grub
sudo sed -i 's/""/"console=tty1 console=ttyS0,115200"/g' /etc/default/grub
sudo sed -i 's/"quiet"/""/g' /etc/default/grub
echo 'GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' | sudo tee -a /etc/default/grub
sudo update-grub2
}

function grub2uefi32 {
sudo apt-get -y install -d -o=dir::cache=/var grub-efi-ia32
sudo chmod -R 777 /var/archives
dpkg -x /var/archives/grub-efi-ia32_2.02~beta3-5_*.deb /var/archives/grub-efi-ia32
dpkg -x /var/archives/grub-efi-ia32-bin_2.02~beta3-5_*.deb /var/archives/grub-efi-ia32-bin
sudo cp -a '/var/archives/grub-efi-ia32-bin/usr/lib/grub/i386-efi' /usr/lib/grub/
sudo grub-install --efi-directory=/boot/ --boot-directory=/boot/gre3 /dev/sda --target=i386-efi --no-nvram
sudo grub-mkconfig -o /boot/gre3/grub/grub.cfg #is the same as bios version
mkdir /boot/EFI/BOOT
cp /boot/EFI/debian/grubia32.efi /boot/EFI/BOOT/BOOTIA32.efi
sudo rm -r /var/archives/grub-efi*
}

function grub2uefi64 {
sudo apt-get -y install -d -o=dir::cache=/var grub-efi-amd64
sudo chmod -R 777 /var/archives
dpkg -x /var/archives/grub-efi-amd64_2.02~beta3-5_*.deb /var/archives/grub-efi-amd64
dpkg -x /var/archives/grub-efi-amd64-bin_2.02~beta3-5_*.deb /var/archives/grub-efi-amd64-bin
sudo cp -a '/var/archives/grub-efi-amd64-bin/usr/lib/grub/x86_64-efi' /usr/lib/grub/
sudo grub-install --efi-directory=/boot/ --boot-directory=/boot/gre6 /dev/sda --target=x86_64-efi --no-nvram
sudo grub-mkconfig -o /boot/gre6/grub/grub.cfg #is the same as bios version
mkdir /boot/EFI/BOOT
cp /boot/EFI/debian/grubx64.efi /boot/EFI/BOOT/BOOTX64.efi
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
EOF
}

function keyboardlang {
sudo mv /etc/default/keyboard /boot
sudo ln -s /boot/keyboard /etc/default/keyboard
}

function resizescript {
sudo apt-get -y install parted
tee /home/pi/init_resize_rootfs.sh <<EOF
#!/bin/bash
sync
echo "Run this script as sudo in case it says command not found"
parted /dev/sda resizepart 2 y 100%
sync
resize2fs /dev/sda2
sync
reboot
EOF
chmod +x /home/pi/init_resize_rootfs.sh
}

function raspbianliteslim {
sudo apt-get -y install alsa-utils apt-transport-https bash-completion binutils blends-tasks bzip2 cu dc device-tree-compiler distro-info-data ed fakeroot file firmware-atheros firmware-brcm80211 firmware-libertas hardlink htop info iw keyutils less man-db manpages ncdu netcat-openbsd netcat-traditional psmisc rsync strace unzip usb-modeswitch usbutils xml-core xz-utils #firmware-misc-nonfree firmware-realtek
}
# firmware alters generic initrd behaviour check?

#dphys-swapfile?
#tobig apt-listchanges aptitude avahi-daemon bind9-host bluez build-essential cifs-utils cpp* dh-python gcc* g++ gdb iso-codes lsb-release nfs-common perl python samba-common

function x86tools {
sudo apt-get -y install pcmciautils lsscsi memtest86+ #amd64/intel microcode?
}

function personal {
sudo apt-get -y install vlan netcat iperf tcpdump minicom tftp lftp dirmngr #nmap
}

fixsudo
decswap
bootfat
grub2serial
grub2uefi32
grub2uefi64
autonetconf
mkrclocal
mksshswitch
cmdlinetxt
keyboardlang
raspbianliteslim
resizescript
x86tools
personal

#sudo poweroff;exit
echo "All Done, gracefully shutdown vmguest `sudo poweroff;exit` to use image"
exit 0
