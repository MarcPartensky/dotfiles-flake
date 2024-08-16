#!/usr/bin/env bash

pause() {
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}
 
log() { echo -e "\n\033[1m${@}\033[0m"; pause; }

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

log 1. Partition the disks.
# Note: you must clear all existing partition tables and data structures from target disks.
# For flash-based storage, this can be done by the blkdiscard command below:
partition_disk () {
 local disk="${1}"
 blkdiscard -f "${disk}" || true

 parted --script --align=optimal  "${disk}" -- \
 mklabel gpt \
 mkpart EFI 1MiB 4GiB \
 mkpart rpool 4096Mib -$((SWAPSIZE + RESERVE))MiB \
 mkpart swap  -$((SWAPSIZE + RESERVE))MiB -"${RESERVE}"MiB \
 set 1 esp on \

 partprobe "${disk}"
}

for i in ${DISK}; do
   partition_disk "${i}"
done

log 2. Setup temporary encrypted swap for this installation only. This is useful if the available memory is small:
for i in ${DISK}; do
   cryptsetup open --type plain --key-file /dev/random "${i}"p3 "${i##*/}"p3
   mkswap /dev/mapper/"${i##*/}"p3
   swapon /dev/mapper/"${i##*/}"p3
done

log 3. LUKS only: Setup encrypted LUKS container for root pool:
for i in ${DISK}; do
   # see PASSPHRASE PROCESSING section in cryptsetup(8)
   printf "YOUR_PASSWD" | cryptsetup luksFormat --type luks2 "${i}"p2 -
   printf "YOUR_PASSWD" | cryptsetup luksOpen "${i}"p2 luks-rpool-"${i##*/}"p2 -
done

log 4. Create encrypted root pool
# shellcheck disable=SC2046
zpool create \
    -o ashift=12 \
    -o autotrim=on \
    -R "${MNT}" \
    -O acltype=posixacl \
    -O canmount=off \
    -O dnodesize=auto \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -O mountpoint=none \
    rpool \
   $(for i in ${DISK}; do
      printf '/dev/mapper/luks-rpool-%s ' "${i##*/}p2";
     done)

log 5. Create root system container:
zfs create -o canmount=noauto -o mountpoint=legacy rpool/root

log Create system datasets, manage mountpoints with mountpoint=legacy
zfs create -o mountpoint=legacy rpool/home
mount -o X-mount.mkdir -t zfs rpool/root "${MNT}"
mount -o X-mount.mkdir -t zfs rpool/home "${MNT}"/home

log 6. Format and mount ESP. Only one of them is used as /boot, you need to set up mirroring afterwards
for i in ${DISK}; do
 mkfs.vfat -n EFI "${i}"p1
done

for i in ${DISK}; do
 mount -t vfat -o fmask=0077,dmask=0077,iocharset=iso8859-1,X-mount.mkdir "${i}"p1 "${MNT}"/boot
 break
done

log System configuration
log 1. Generate system configuration:
nixos-generate-config --root "${MNT}"


log 2. Edit system configuration: 
log 3. To set networking.hostId: networking.hostId = "abcd1234";
nano "${MNT}"/etc/nixos/hardware-configuration.nix

log 4. If using LUKS, add the output from following command to system configuration
tee <<EOF
  boot.initrd.luks.devices = {
EOF

for i in ${DISK}; do echo \"luks-rpool-"${i##*/}p2"\".device = \"${i}p2\"\; ; done

tee <<EOF
};
EOF

log 5. Install system and apply configuration
nixos-install  --root "${MNT}"

log 6. Unmount filesystems
cd /
umount -Rl "${MNT}"
zpool export -a

log 7. Reboot
reboot

# 8. Set up networking, desktop and swap.
# 9. Mount other EFI system partitions then set up a service for syncing their contents.
