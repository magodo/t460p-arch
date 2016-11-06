Arch Linux install helper for thinkpad t460p
============================================

This is only meant to provide a simple, basic and self-usage install helper for thinkpad t460p only. It will ultimately give user a console as a start point. For a full installation process I have went through, please check my [blog](http://magodo.github.io/os/2016/11/06/Install-ArchLinux-on-thinkpad-t460p.html)

### Precondition ###

Following conditions need to meet:

* EFI boot mode is enabled from firmware (press F1 during boot)
* Network is reachable via either ethernet or wireless

### Usage ###

Two scripts are provided during different phases: *install phase* and *configuration phase*

For installation phase, you will be booted via a live system from usb media for example. Then you will need to download these two scripts from web or via another usb media(e.g. I put it in a movable disk and I have to install `ntfs-3g` first and then mount the disk via `mount -t ntfs-3g ...` ). 

Afterwards, you can just run 1st script: *install.sh*. This script perform following actions:

* verify boot mode
* connect network
* update system clock
* identify the disk device
* (opt)create and format partitions
* mount file system
* select live system mirrors
* install the base, wireless and microcode packages
* fstab
* chroot

They are ordered by the arch [wiki](https://wiki.archlinux.org/index.php/installation_guide)

At the end of this script, it will run `arch-chroot`, which will immediately stop the process and bring you to the changed rootfs. This is why we have 2 scripts. Just before `arch-chroot`, we have copied the 2nd script, i.e. *config.sh* to the newly created fs. Therefore, after exit from *install.sh*, just run *config.sh*.

In the *config.sh*, we perform following actions:

* connect to internet
* time zone && Locale && hostname
* initramfs
* passwd
* boot loeader
* reboot

After exit from *config.sh*,  please exit chroot(`exit`) and `umount -R /mnt`, then `reboot`.
