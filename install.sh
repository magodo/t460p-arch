#!/bin/bash
 
#########################################################################
# Author: Zhaoting Weng
# Created Time: Sat 05 Nov 2016 01:37:08 PM CST
# Description: Install arch linux on thinkpad t460p for UEFI + GPT (1)
# Pre-requisite: 
#       * EFI boot mode is enabled from firmware (press F1 during boot)
#       * Network is reachable via either ethernet or wireless
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
    echo -e "\t*        verify boot mode"
    echo -e "\t*        connect network"
    echo -e "\t*        update system clock"
    echo -e "\t*        identify the disk device"
    echo -e "\t*(opt)   create and format partitions"
    echo -e "\t*        mount file system"
    echo -e "\t*        select live system mirrors"
    echo -e "\t*        install the base, wireless and microcode packages"
    echo -e "\t*        fstab"
    echo -e "\t*        chroot"
    echo 
    echo "options:"
    echo -e "\t-h       show this help"
    echo -e "\t-n       don't create/format partition (since it might have been done)"
    
}

#########################################
# Parse CMD line optios
#########################################

OPTIND=1		# Process arguments
FLAG_NO_PART=0

while getopts :hn opt; do
    case $opt in
        \?)
            exit_error "Invalid option: ${OPTARG}!"
	    ;;
        h)	    
	    usage
	    exit 0
	    ;;
	n)
            FLAG_NO_PART=1
	    ;;
    esac
done

#########################################
# Pre-installation
#########################################

#---------------------------
# verify boot mode         
#---------------------------
echo
cecho cyan "[Verify boot mode]"
echo
[[ -d /sys/firmware/efi/efivars ]] || exit_error "UEFI mode is not enabled!"

#---------------------------
# Connect network
#---------------------------
echo
cecho cyan "[Connect network]"
echo

check_network
if [[ $? = 1 ]]; then
    echo "Setting up wireless network"
    kill `pidof dhcpcd` `pidof wpa_supplicant`
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
# Update system clock
#---------------------------
echo
cecho cyan "[Update system clock]"
echo
timedatectl set-ntp true

#---------------------------
# Find the disk device
#---------------------------
echo
cecho cyan "[Find the disk device]"
echo
DISKS=(`for dev in /dev/sd*; do echo ${dev%[0-9]}; done | sort -u`)
NUM_OF_DISK=${#DISKS[@]}
if [[ $NUM_OF_DISK > 1 ]]; then
    echo -e "\tWe found following disk devices in your system:"
    index=0
    while  [[ $index != $(($NUM_OF_DISK)) ]]; do
        echo -e "\t$index. ${DISKS[$index]}"
        ((index+=1))
    done
    echo -ne "\tChoose your disk device (\"0\"-\"$(($NUM_OF_DISK-1))\"): "
    read index
    while [[ $index > $(($NUM_OF_DISK-1)) || $index < 0 ]]; do
        echo -ne "\tPlease choose index in range (\"0\"-\"$(($NUM_OF_DISK-1))\"): "
        read index
    done
    DISK=${DISKS[$index]}
else
    DISK=${DISKS[0]}
fi


#---------------------------
# (option) create and format partition
#---------------------------
if [[ $FLAG_NO_PART = 0 ]]; then
    echo
    cecho cyan "[Create and format partitions for UEFI+GPT]"
    echo
    echo -e "\tWe are going to partition with following setup:"
    echo -e "\t\tDevice         Start       End         Size        Type        Flags"
    echo -e "\t\t${DISK}1       1049kB      513MB       512MB	fat32       boot, esp"
    echo -e "\t\t${DISK}2       513MB       215GB       215GB       ext4"
    echo -e "\t\t${DISK}3       215GB       225GB       10240MB     linux-swap(v1)"
    echo -e "If you want to change this setup, please feel free to change this script"
    echo 
    echo "*WARNING*"
    echo -n "This will permanently clear anything in your disk, do you wana go on (y/n)? "
    read is_goon
    while [[ $is_goon != y && $is_goon != n ]]; do
        echo "Invalid argument, please enter \"y\" or \"n\""
        read is_goon
    done
    if [[ $is_goon = n ]]; then
        exit_msg "Bye :)"
    else
        #################
        # 1. partition  #
        #################
    
        echo "partitioning..."
    
        # create ESP and boot flag
        parted ${DISK} mkpart ESP fat32 1MB 513MB
        parted ${DISK} set 1 boot on
    
        # create root partition
        parted $DISK mkpart primary ext4 513MB 215GB
    
        # create swap partition
        parted $DISK mkpart primary linux-swap 215GB 225GB
    
        #################
        # 2. format fs  #
        #################
    
        echo "making file system..."
    
        mkfs.fat -F32 ${DISK}1
        mkfs.ext4 ${DISK}2
        mkswap ${DISK}3
        swapon ${DISK}3
    fi
fi



#---------------------------
# mount fs
#---------------------------
echo
cecho cyan "[Mount Fs]"
echo
mount ${DISK}2 /mnt
[[ ! -d /mnt/boot ]] && mkdir /mnt/boot
mount ${DISK}1 /mnt/boot



#########################################
# Installation
#########################################

#---------------------------
# select live system mirrors
#---------------------------
echo
cecho cyan "[Select live system mirrors]"
echo
mirrorlist=/etc/pacman.d/mirrorlist
mirror163=`sed -n -e '/163.com/p' $mirrorlist`
sed -i -e "/163.com/ d" $mirrorlist             # remove the 163 mirror 
sed -i -e "1 i $mirror163"  $mirrorlist         # insert 163 mirror at the head of list


#---------------------------
# install basic packages
#---------------------------
echo
cecho cyan "[Install base, wireless, microcode packages]"
echo
pacstrap /mnt base iw wpa_supplicant dialog intel-ucode


#---------------------------
# generate fstab
#---------------------------
echo
cecho cyan "[Fstab]"
echo
genfstab -U /mnt >> /mnt/etc/fstab

#---------------------------
# chroot
#---------------------------
cecho cyan "[chroot]"
cecho orange "Before chroot, copy the second scripts \"config.sh\" to root directory of the target file system."
cecho orange "After chroot, just run \"./config.sh\""
cp `dirname $0`/config.sh /mnt/
arch-chroot /mnt
