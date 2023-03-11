#!/bin/bash

set -ex

#
# CONFIG
#

# Disk to install Void Linux on. You can use 'lsblk' to find the name of the disk.
DISK="/dev/nvme0n1"

# Minimum of 100M: https://wiki.archlinux.org/title/EFI_system_partition
EFI_PARTITION_SIZE="256M"		

# Name to be used for the hostname of the Void installation
HOSTNAME="void"

# Name to be used volume group
VOLUME_GROUP="voidvg"

# Filesystem to be used
FILE_SYSTEM="ext4"

# 'musl' for musl, '' for glibc.
LIBC=""

#
# USER INPUT
#

echo -e "\nEnter password to be used for disk encryption\n"
read LUKS_PASSWORD
ROOT_PASSWORD=$LUKS_PASSWORD 

#
# VARIABLES
#

UNSPECIFIED_ERROR_CODE=1

#
# CREATE EFI PARTITION AND LUKS PARTITION
#

# Wipes disk from magic strings to make the filesystem invisible to libblkid: https://linux.die.net/man/8/wipefs
wipefs --all $DISK

# Set partition names based on disk name for most common disks by driver: https://superuser.com/a/1449520/393604
if [[ $DISK == *"sd"* ]]; then
	EFI_PARTITION=$(echo $DISK'1')
	LUKS_PARTITION=$(echo $DISK'2')
elif [[ $DISK == *"nvme"* ]]; then
	EFI_PARTITION=$(echo $DISK'p1')
	LUKS_PARTITION=$(echo $DISK'p2')
else
	exit 1
fi

# Create EFI parition with selected size and LUKS partition with remaining size. To create these interactively you can use 'fdisk' or the friendlier 'cfdisk'
printf 'label: gpt\n, %s, U, *\n, , L\n' "$EFI_PARTITION_SIZE" | sfdisk -q "$DISK" # A warning about existing signature can be ignored

#
# CREATE FILE SYSTEM ON EFI PARTITION
#

# Create EFI file system (on physical parition efi)
mkfs.vfat $EFI_PARTITION

#
# ENCRYPT LUKS PARTITION
#

echo $LUKS_PASSWORD | cryptsetup -q luksFormat --type luks1 $LUKS_PARTITION

#
# CREATE VOLUME GROUP, LOGICAL ROOT PARTITION, FILE SYSTEM ON ROOT
#

# Open LUKS partition into dev/mapper/luks
echo $LUKS_PASSWORD | cryptsetup luksOpen $LUKS_PARTITION luks

# Create volume group on device
vgcreate $VOLUME_GROUP /dev/mapper/luks

# Ceate logical root volume in existing volume group
# Home and swap volumes can also be created, but I don't see a need for more than one partition at this time.
lvcreate --name root --extents 100%FREE $VOLUME_GROUP

# Create root file system
mkfs.$FILE_SYSTEM -L root /dev/$VOLUME_GROUP/root

#
# MOUNT EFI AND ROOT PARTITIONS
#

# Mount root partition
mount /dev/$VOLUME_GROUP/root /mnt

# Mount EFI partition (needs to be mounted after root partition, to not be overwritten I assume)
mkdir -p /mnt/boot/efi
mount $EFI_PARTITION /mnt/boot/efi/

#
# INSTALL SYSTEM
#

# Install Void base system to the root partition, echo y to accept and import repo public key
echo y | xbps-install -Sy -R https://repo-default.voidlinux.org/current/$LIBC -r /mnt base-system cryptsetup grub-x86_64-efi lvm2

#
# SETUP ROOT USER
#

# Change ownership and permissions of root directory
chroot /mnt chown root:root /
chroot /mnt chmod 755 /

echo -e "$ROOT_PASSWORD\n$ROOT_PASSWORD" | xchroot /mnt passwd -q root

#
# SOME CONFIGUARTION
#

#Set hostname and language/locale
echo $HOSTNAME > /mnt/etc/hostname

if [[ -z $LIBC ]]; then
  echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
  echo "en_US.UTF-8 UTF-8" >> /mnt/etc/default/libc-locales
  xchroot /mnt xbps-reconfigure -f glibc-locales
fi

#
# FSTAB CONFIGURATION
#

#Add lines to fstab, which determines which partitions/volumes are mounted at boot
echo -e "/dev/$VOLUME_GROUP/root	/	$FILE_SYSTEM	defaults	0	0" >> /mnt/etc/fstab
echo -e "$EFI_PARTITION	/boot/efi	vfat	defaults	0	0" >> /mnt/etc/fstab


#
# GRUB CONFIGURATION
#

# Modify GRUB config to allow for LUKS encryption.
echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub

LUKS_UUID=$(blkid -s UUID -o value $LUKS_PARTITION)
kernel_params="rd.lvm.vg=$VOLUME_GROUP rd.luks.uuid=$LUKS_UUID"
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$kernel_params /" /mnt/etc/default/grub

#
# AUTOMATICALLY UNLOCK ENCRYPTED DRIVE ON BOOT
#

# Generate keyfile
xchroot /mnt dd bs=1 count=64 if=/dev/urandom of=/boot/volume.key

# Add the key to the encrypted volume
echo $LUKS_PASSWORD | xchroot /mnt cryptsetup -q luksAddKey $LUKS_PARTITION /boot/volume.key

# Change the permissions to protect generated the keyfile
xchroot /mnt chmod 000 /boot/volume.key
xchroot /mnt chmod -R g-rwx,o-rwx /boot

#Add keyfile to /etc/crypttab
echo "cryptroot UUID=$LUKS_UUID	/boot/volume.key	luks" >> /mnt/etc/crypttab

#Add keyfile and crypttab to initramfs
echo -e "install_items+=\" /boot/volume.key /etc/crypttab \"" > /mnt/etc/dracut.conf.d/10-crypt.conf

#
# COMPLETE SYSTEM INSTALLATION
#

# Install GRUB bootloader
xchroot /mnt grub-install $DISK

# Ensure an initramfs is generated
xchroot /mnt xbps-reconfigure -fa

#
# UNMOUNT
#

# Unmount root volume
umount -R /mnt

echo "Install is complete, reboot."
