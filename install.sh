#!/usr/bin/env bash

log() { echo -e "\n\033[1m${@}\033[0m"; }
pause() { read -p "Press any key to continue... " -n1 -s }

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

log Destroying zfs pool rpool and bpool just in case
swapoff -a
zpool import -fa
for i in ${DISK}; do
   zpool labelclear -f $i
done
zpool destroy -f bpool
zpool destroy -f rpool
zpool export -a

log Unmounting filesystems just in case
# ---
umount -Rl "${MNT}"

log Enabling Nix Flakes functionality
# ---
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf


log Installing programs needed for system installation


log Partition the disks
# ---
partition_disk () {
 local disk=$1
 blkdiscard -f $disk || true

 parted --script --align=optimal  $disk -- \
     mklabel gpt \
     mkpart swap  1MiB $((SWAPSIZE + 1))MiB \
     mkpart rpool $((SWAPSIZE + 1))MiB -$((RESERVE + 200))MiB \
     mkpart bpool -$((RESERVE + 200))MiB -$((RESERVE + 50))MiB \
     mkpart EFI -$((RESERVE + 50))MiB -$((RESERVE + 2))MiB \
     mkpart BIOS -$((RESERVE + 2))MiB -$((RESERVE + 1))MiB \
     set 4 esp on \
     set 5 bios_grub on \
     set 5 legacy_boot on

 partprobe $disk
 udevadm settle
}

for i in $DISK; do
   partition_disk $i || exit 1
done

log disk $DISK


log Creating boot pool
# ---
# shellcheck disable=SC2046
createbpool="zpool create \
    -o compatibility=grub2 \
    -o ashift=12 \
    -o autotrim=on \
    -O acltype=posixacl \
    -O canmount=off \
    -O compression=lz4 \
    -O devices=off \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -m /boot \
    -R $MNT \
    bpool \
    `for i in $DISK; do
       printf '%s ' ${i}p3
     done`"
echo $createbpool
eval $createbpool
# for i in ${DISK}; do
#    cryptsetup open --type plain --key-file /dev/random "${i}"p3 "${i##*/}"p3
#    mkswap /dev/mapper/"${i##*/}"p3
#    swapon /dev/mapper/"${i##*/}"p3
# done

log Creating root pool
# ---
# shellcheck disable=SC2046
echo $POOLPASS | zpool create \
    -o ashift=12 \
    -o autotrim=on \
    -R $MNT \
    -O acltype=posixacl \
    -O canmount=off \
    -O compression=zstd \
    -O dnodesize=auto \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -o feature@encryption=enabled \
    -O encryption=on \
    -O keyformat=passphrase \
    -m / \
    rpool \
   $(for i in $DISK; do
      printf '%s ' "${i}p2";
     done)


log Creating encrypted root system container
# ---
echo $POOLPASS | zfs create \
    -o canmount=off \
    -o mountpoint=none \
    -o encryption=on \
    -o keylocation=prompt \
    -o keyformat=passphrase \
    rpool/nixos

log Create root system container
zfs create -o canmount=noauto -o mountpoint=legacy rpool/root
zfs create -o mountpoint=legacy rpool/home
mount -o X-mount.mkdir -t zfs rpool/root "${MNT}"
mount -o X-mount.mkdir -t zfs rpool/home "${MNT}"/home

log Format and mount ESP. Only one of them is used as /boot, you need to set up mirroring afterwards
for i in ${DISK}; do
    mkfs.vfat -n EFI "${i}"p1
done

for i in ${DISK}; do
    mount -t vfat -o fmask=0077,dmask=0077,iocharset=iso8859-1,X-mount.mkdir "${i}"p1 "${MNT}"/boot
    break
done

log Generate system configuration:
nixos-generate-config --root "${MNT}"

log Edit system configuration with new host
sed -i "s|\"abcd1234\"|\"nixos\"|g" \
  "${MNT}"/etc/nixos/hardware-configuration.nix
sed -i "s|\"abcd1234\"|\"nixos\"|g" \
  "${MNT}"/etc/nixos/configuration.nix

# log If using LUKS, add the output from following command to system configuration
# tee <<EOF
#   boot.initrd.luks.devices = {
# EOF
# for i in ${DISK}; do echo \"luks-rpool-"${i##*/}p2"\".device = \"${i}p2\"\; ; done
# tee <<EOF
# };
# EOF
pause
vim "${MNT}"/etc/nixos/configuration.nix

log Install system and apply configuration
nixos-install  --root "${MNT}" --show-trace

log Unmount filesystems
cd /
umount -Rl "${MNT}"
zpool export -a

log you should reboot
# reboot
