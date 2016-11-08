#!/bin/bash
 
#########################################################################
# Author: Zhaoting Weng
# Created Time: Sat 05 Nov 2016 01:37:08 PM CST
# Description: Install arch linux on thinkpad t460p for UEFI + GPT (2)
# Pre-requisite: 
#       * install.sh is run with no error
#########################################################################

#set -ex

#########################################
# Utilities
#########################################


# Colorful output

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

declare -A COLOR_MAP=( [red]=$RED [green]=$GREEN [orange]=$ORANGE [blue]=$BLUE \
    [purple]=$PURPLE [cyan]=$CYAN [nc]=$NC) 

function cecho()
{
    color=$1
    msg=$2

    echo -e "${COLOR_MAP[$color]}${msg}${COLOR_MAP[nc]}"
}

# Exit with error message and error code 1
function exit_error()
{
    cecho red "Error: $1"
    exit 1
}

# Exit with message and error code 0
function exit_msg()
{
    cecho blue "$1"
    echo 0
}

# Check network connection
#
# ret:   0 means there is Internet connection
#        1 means there is Internet connection

function check_network()
{
    for t in 1 2 3 4; do
        [[ $t = 4 ]] && echo "No connection to Internet..." && return 1
        ping -c 1 archlinux.org && echo "Internet connected!" && break
        echo -e "\tPing failed. Retry $1..."
        sleep $t
    done
    return 0
}

function usage()
{
    echo "usage: $0 [options]"
    echo
    echo "description: this script perfrom following operations (ordered on http://wiki.archlinux.org/index.php/installation_guide):"
    echo -e "\t*    connect to internet"
    echo -e "\t*    time zone && Locale && hostname"
    echo -e "\t*    initramfs"
    echo -e "\t*    passwd"
    echo -e "\t*    boot loeader"
    echo -e "\t*    reboot"
    echo 
    echo "options:"
    echo -e "\t-h       show this help"
}

#########################################
# Parse CMD line optios
#########################################

OPTIND=1		# Process arguments

while getopts :h opt; do
    case $opt in
        \?)
            exit_error "Invalid option: ${OPTARG}!"
	    ;;
        h)	    
	    usage
	    exit 0
	    ;;
    esac
done


#########################################
# Configuration
#########################################

#---------------------------
# Connect network
#---------------------------
echo
cecho cyan "[Connect network]"
echo

check_network
if [[ $? = 1 ]]; then
    echo "Setting up wireless network"
    PIDS_1=`pidof dhcpcd`
    PIDS_2=`pidof wpa_supplicant`
    [[ -n $PIDS_1 || -n $PIDS_2 ]] && kill $PIDS_1 $PIDS_2  # make sure there is no wpa_supplicant or dhcpcd running
    WL_INTERFACE=`iw dev | grep Interface | cut -d" " -f 2`
    ip link set $WL_INTERFACE up
    echo -e "\tFollowing APs with strong signals are found:"
    iw dev $WL_INTERFACE scan | grep SSID | head
    echo -ne "\tEnter the SSID you want to connect: "
    read SSID
    echo -ne "\tEnter passwd: "
    read PASSWD
    wpa_supplicant -B -D n180211,wext -i $WL_INTERFACE -c <(wpa_passphrase $SSID $PASSWD)
    dhcpcd $WL_INTERFACE
    
    # check network
    check_network || exit_error "Setup wireless network failed!"
fi

#---------------------------
# time zone, locale, hostname
#---------------------------
echo
cecho cyan "[Time zone && Locale && hostname]"
echo

# time zone
rm /etc/localtime
ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc
# locale
sed -i -e "s/^#\(en_US.UTF-8 UTF-8\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# hostname
echo t460p > /etc/hostname


#---------------------------
# initramfs
#---------------------------
echo
cecho cyan "[initramfs]"
echo
mkinitcpio -p linux


#---------------------------
# passwd
#---------------------------
echo
cecho cyan "[passwd]"
echo
passwd


#---------------------------
# boot loader
#---------------------------
echo
cecho cyan "[boot loader]"
echo
bootctl --path=/boot install

# config loader.conf

cat > /boot/loader/loader.conf << EOL
default arch
timeout 3
editor 0
EOL

# config boot entry: arch.conf
DEVICE_ROOT=`mount -l | grep "on / " | cut -d" " -f 1`
cat > /boot/loader/entries/arch.conf << EOL
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=PARTUUID=`blkid -s PARTUUID -o value ${DEVICE_ROOT}` rw
EOL

#---------------------------
# set font
#---------------------------
font="iso02-12x22"
setfont $font
echo "FONT=${font}" > /etc/vconsole.conf   # this might distort other ttys, use back to default one, just enter `setfont`

#---------------------------
# Install base-devel package
#---------------------------
pacman -S --noconfirm base-devel  # don't know why can't install via pacstrap from live system

#---------------------------
# reboot
#---------------------------
echo
cecho cyan "[reboot]"
echo
cecho orange "Please exit chroot and umount -R /mnt, then reboot"
exit
