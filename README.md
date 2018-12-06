# x86raspbianfy
It's just a script to create a <1GB Debian Stretch image for x86(i686-nonpae) based pc/notebook/embedded hardware, but mimicking raspbian-lite(raspberry pi OS) behaviour in the sense and ease of imaging, disklayout and setup connectivity. It will be created in full non-interactive automation using qemu delivering a raw image file.

## Features
For example 'ssh' service can be enabled by creating a file named "ssh" on the boot partition, also wifi can be configured by adding a file "wpa_supplicant.conf" there and other ethernet adapters can be connected without the need to configure them first in /etc/network/interfaces (when using dhcp) see "dhcpcd.conf". Like a raspbian-lite image the 'boot' partition is FAT based for easy editing by other OS and comes loaded with Grub2(BIOS&UEFI-ia32/x64) configured for both VGA or Serial Console(115200) based booting. In addition it also comes with a '(boot)/keyboard' file in which you can change layout from UK to US. The 'rootfs' partition can be easily expanded with a simple buildin resize script. The 'sudo' command has been configured to require no password, but it is required to type 'sudo' for all system related commands(intended). Just like raspbian-lite it also comes with /etc/rc.local working. Because of the size restrictions < 1GB it comes with less tools than raspbian-lite but hopefully enough to get you started.

It also has similar quirks as raspbian-lite like its keyboardlayout/timezone are by default UK/UTC and locals are "en_GB.UTF-8". This is still intended to stay as close to raspbian-lite in sense of minimizing differences. It also complains like raspbian about FAT boot partition not being able to handle linking, it lacks optimization for 64bit support like raspbian but it still compatible with 64 bit systems and its bootloaders. 

## Why?
If your 'arm' cpu based raspbian pi project won't cut it performance wise, or lacks compatible software or usb device drivers available and optimized for the aging x86 hardware this project might be the fastest way to jump ship/compare behaviour. 
Another reason for this project is that AdaFruit Read Only Raspbian system modification script https://learn.adafruit.com/read-only-raspberry-pi/overview also has been confirmed working on debian stretch i686 making x86 attractive again for simple embedded power-cut/outage usecases.
Finally its 2018 and no time should be wasted on the installing-phase of a OS especially on old, slow hardware with lacking/slow usb or buggy optical drive boot. Just image, connect to ssh, keyboard&monitor or even serialconsole and instantly start.

## Requirements
There are 3 bash scripts(+qemu payload files) and around 2GB in diskspace and a active internet connection(~15MBit) for the host and vmguest is needed when creating a 1GB image.

## How it works?
The 'host.sh' script prepares the vmhost in this case ubuntu 18.04.1 amd64 desktop for qemu-kvm usage by installing qemu, virtualbox and downloading debian and ubuntu OS installation iso files. Following 'host.sh' creates a disk img and mounts corresponding OS install iso while initiating the vmguest with telnet console monitor capabilities.
After the guest machine started, the 'host2guest.sh' script uses 'qcmpayload.txt' and runs between host and vmguest via qemu console monitor(telnet) injecting scripted input. This whole automation takes control for installing the OS into the vmguest and after OS install will run the neccesary steps to mimic raspbian behaviour by running the 'rf.sh' script inside the vmguest.

After ~45 minutes(hardcoded time), there will be a < 1GB 'disk-distro-arch-1GB.img' file which you can image to any pc you like. For customization of your image before build (edit config files/apt-get packages) you probably want to modify 'rf.sh', if you want to resize/change boot/rootfs/filesystem partition you have to look carefull at 'qcmpayload.txt' but its not hard.

## Start?
Download/clone this github repo on a ubuntu 18.04 amd64(32bit may work)desktop and run the 'host.sh' script with '5' arguments:
* first for action (prepare/create/modify/convertovb) 
* second for distro (debian/ubuntu)
* third for release codename(jessie/stretch/xenial/bionic)
* fourth for architecture (i386/amd64)
* fifth for fixed imgsizes in GigaBytes (1GB/2GB)

Open a terminal and cd to the downloaded files:

```
chmod +x *.sh #makes the scripts executable
./host.sh prepare #install qemu&virtualbox and debian/ubuntu guest OS install isos
./host.sh create debian stretch i386 1GB #asks for sudo hurry and will run for ~45 minutes don't interfere with own keyboard input!
./host.sh modify ubuntu xenial amd64 2GB #no qemu payload, just modify the guest manually from the screen/keyboard
./host.sh convertovb ubuntu xenial amd64 2GB #converts the img to a Oracle VirtualBox OVA appliance "needs testing"
```

After imaging and running the image on bare metal target system its a good start to change the timezone and expand the rootfs or change password. Before that it may be wise to setup ssh or wpa_supplicant just follow raspbian documentation:

```
sudo dpkg-reconfigure tzdata #reconfigure your timezone
sudo ./init_resize_rootfs.sh #expands rootfs to max bare metal disk and reboots 
``` 

## TODO's
- /etc/dhcpcd.conf unlink and copy form /boot otherwise apt stalls
- complete raspbianlite full package selection
- optimize boot/rootfs partitionsize / freespace
- fix uuid change on debian
- adafruit readonly script adds to cmdline.txt instead of grub "fastboot noswap ro"

## Links
- [qemu console monitor scripting telnet](https://stackoverflow.com/questions/33362322/how-in-qemu-send-mouse-move-mouse-button-sendkey-via-some-api)
- [default raspbian-lite packages](https://n8henrie.com/2017/09/list-of-default-packages-on-raspbian-stretch-and-stretch-lite/)
- [raspbian-lite boot behaviour](https://www.raspberrypi.org/forums/viewtopic.php?t=206783)
- [raspbian fat16/fat32](https://www.raspberrypi.org/forums/viewtopic.php?t=18540)
- [grub2 serial console](https://www.hiroom2.com/2017/06/19/debian-9-grub2-and-linux-with-serial-console/)
- [debian 9 stretch udev ethernet names](https://www.itzgeek.com/how-tos/linux/debian/change-default-network-name-ens33-to-old-eth0-on-debian-9.html)
- [debian 9 stretch systemd eth names](https://unix.stackexchange.com/questions/321755/eth0-no-longer-claiming-address-on-debian-jessie)
- [debian 9 stretch rc.local missing](https://www.itechlounge.net/2017/10/linux-how-to-add-rc-local-in-debian-9)
- [debian installer systemd bug didn't show up](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=820074;msg=12)
- [raspbian ssh boot partition toggle](https://www.raspberrypi.org/forums/viewtopic.php?t=198660)
- [raspbian wpa_supplicant boot setting](https://www.raspberrypi.org/forums/viewtopic.php?t=206783)
- [raspbian ssh/wifi toggle scripts](https://github.com/RPi-Distro/raspberrypi-sys-mods/tree/master/debian)
- [ubuntu cloud image on bare metal](https://pardini.net/blog/2016/11/05/running-ubuntu-cloud-images-with-cloud-init-on-all-infrastructure-from-cloud-to-bare-metal/)
- [debian installer cannot find cdrom](https://github.com/pbatard/rufus/issues/501)
- [convert qcow2 with qemu to raw](https://unix.stackexchange.com/questions/30106/move-qcow2-image-to-physical-hard-drive)
- [raspbian change disk identifier uuid](https://www.raspberrypi.org/forums/viewtopic.php?t=191775)
- [change symbolic link ownership dhcpcd.conf?](https://unix.stackexchange.com/questions/218557/how-to-change-ownership-from-symbolic-links/218559)
- [generic > targeted initrd after install](https://askubuntu.com/questions/16007/switch-to-a-targeted-initrd-after-setup)
- [wpa_supplicant systemd dhcpcd](http://nixventure.blogspot.com/2016/04/debian-wpasupplicant-systemd.html)
- [dhcpcd raspberry](https://www.raspberrypi.org/forums/viewtopic.php?f=36&t=191453&start=25)
- [wpa dhcpcd](https://forum.voidlinux.org/t/wpa-supplicant-and-dhcpcd-require-restart-after-reboot/3396)
- [raspberry wifi](https://www.raspberrypi.org/forums/viewtopic.php?t=191061)
- [grub uuid disk cloning](https://ubuntuforums.org/showthread.php?t=1682129)
- [qemu problem without error](https://unix.stackexchange.com/questions/362952/libvirt-qemu-kvm-fails-on-guest-creation-without-any-specific-error-message)
