#!/usr/bin/env bash

log() { echo -e "\n\033[1m${@}\033[0m"; }

log Checking root
mustberoot() {
    log You must be root
    exit 1
}
whoami | grep root || mustberoot

log Checking connectivity
curl -s google.com > /dev/null || exit 1

log Loading zfs module first
modprobe zfs || exit 1

log Installing packages
nix-env -f '<nixpkgs>' -iA git jq parted fzf

echo ""
lsblk
echo ""

# read -p "disk: " DISK
DISK=`lsblk | grep disk | grep -v SWAP | awk '{print $1}' | fzf`
DISK=`echo /dev/$DISK`
log $disk
read -p "swapsize GiB: " SWAPSIZEGIB
read -p "reserve GiB: " RESERVEGIB
read -sp "password: " POOLPASS

EMAIL="marc@marcpartensky.com"
NAME="Marc Partensky"

RESERVE=$((RESERVEGIB * 1024))
SWAPSIZE=$((SWAPSIZEGIB * 1024))


MNT=$(mktemp -d)

