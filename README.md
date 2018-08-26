# x86raspbianfy
It's just a script to create a <1GB Debian Stretch image for x86(i686-nonpae) based pc/notebook/embedded hardware, but mimicking raspbian-lite(raspberry pi OS) behaviour in the sense and ease of imaging, disklayout and setup connectivity. It will be created in full non-interactive automation using qemu delivering a raw image file.

## Features
For example 'ssh' service can be enabled by creating a file named "ssh" on the boot partition, also wifi can be configured by adding a file "wpa_supplicant.conf" there and other ethernet adapters can be connected without the need to configure them first in /etc/network/interfaces (when using dhcp). Like a raspbian-lite image the 'boot' partition is FAT based for easy editing by other OS and comes loaded with Grub2(BIOS&UEFI-ia32/x64) configured for both VGA or Serial Console(115200) based booting. In addition it also comes with a '(boot)/keyboard' file in which you can change layout from UK to US. The 'rootfs' partition can be easily expanded with a simple buildin resize script. The 'sudo' command has been configured to require no password, but it is required to type 'sudo' for all system related commands(intended). Just like raspbian-lite it also comes with /etc/rc.local working. Because of the size restrictions < 1GB it comes with less tools than raspbian-lite but hopefully enough to get you started.

It also has similar quirks as raspbian-lite like its keyboardlayout/timezone are by default UK/UTC and locals are "en_GB.UTF-8". This is still intended to stay as close to raspbian-lite in sense of minimizing differences. It also complains like raspbian about FAT boot partition not being able to handle linking, it lacks optimization for 64bit support like raspbian but it still compatible with 64 bit systems and its bootloaders. 

## Why?
If your 'arm' cpu based raspbian pi project won't cut it performance wise, or lacks compatible software or usb device drivers available and optimized for the aging x86 hardware this project might be the fastest way to jump ship/compare behaviour. 
Another reason for this project is that AdaFruit Read Only Raspbian system modification script https://learn.adafruit.com/read-only-raspberry-pi/overview also has been confirmed working on debian stretch i686 making x86 attractive again for simple embedded power-cut/outage usecases.
Finally its 2018 and no time should be wasted on the installing-phase of a OS especially on old, slow hardware with lacking/slow usb or buggy optical drive boot. Just image, connect to ssh, keyboard&monitor or even serialconsole and instantly start.

## How it works?
There are 4 scripts and around 1,5GB in diskspace and a active internet connection for the host and vmguest is needed. The 'host.sh' prepares the vmhost in this case ubuntu 18.04.1 amd64 desktop for qemu-kvm usage by installing qemu and creating a 1GB vmguest disk and download "debian-9.5.0-i386-netinst.iso" (~400MB) and initiate the vmguest with telnet console monitor capabilities.
After the guest machine started, the first script will run the 'host2guest.sh' script which uses 'qcmpayload.txt' for qemu console monitor scripted input via a telnet session. This whole automation takes control for installing the OS into the vmguest and after OS install will run the neccesary steps to mimic raspbian behaviour by running the 'rf.sh' script inside the vmguest.

After ~45 minutes(hardcoded time), there will be a < 1GB 'disk1GB.img' file which you can image to any pc you like. For customization of your image before build (edit config files/apt-get packages) you probably want to modify 'rf.sh', if you want to resize/change boot/rootfs/filesystem partition you have to look carefull at 'qcmpayload.txt' but its not hard.

## Start?
Download/clone this github repo and run the 'host.sh' script on a ubuntu 18.04 amd64(32bit may work) desktop, after typing your sudo password let it run for ~45 minutes and don't interfere with own keyboard input in the qemu-monitor. Open a terminal and cd to the downloaded files:

```
chmod +x *.sh #makes the scripts executable
./host.sh #asks for sudo and will run for ~45 minutes
```

After imaging and running the image on bare metal target system its a good start to change the timezone and expand the rootfs or change password. Before that it may be wise to setup ssh or wpa_supplicant just follow raspbian documentation:

```
sudo dpkg-reconfigure tzdata #reconfigure your timezone
sudo ./init_resize_rootfs.sh #expands rootfs to max bare metal disk and reboots 
``` 

## TODO's
- dhcpcd static ip
- adafruit readonly script adds to cmdline.txt instead of grub "fastboot noswap ro"
- compare initrd (generic) before/after additonal firmware?
- 64bit image already works but use 64bit.iso uses qemu system-x86_64 and remove one step from qcmpayload (sendkey up) at kernel selection

## Links
- [qemu console monitor scripting telnet](https://stackoverflow.com/questions/33362322/how-in-qemu-send-mouse-move-mouse-button-sendkey-via-some-api)
- [default raspbian-lite packages](https://n8henrie.com/2017/09/list-of-default-packages-on-raspbian-stretch-and-stretch-lite/)
- [raspbian-lite boot behaviour](https://www.raspberrypi.org/forums/viewtopic.php?t=206783)
