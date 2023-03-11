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
VOLUME_GROUP="void"

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
	EFI_PARTITION=$(echo $disk_selected'1')
	LUKS_PARTITION=$(echo $disk_selected'2')
elif [[ $DISK == *"nvme"* ]]; then
	EFI_PARTITION=$(echo $disk_selected'p1')
	LUKS_PARTITION=$(echo $disk_selected'p2')
elif
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
# CREATE VOLUME GROUP, LOGICAL ROOT PARTITION, FILE SYSTEM ON LUKS PARTITION
#

# I could probably get rid of the volume group
# LVM is a system for partitioning and managing logical volumes, or filesystems, but it has nothing to do with encryption in itself. LVM is a much more advanced and flexible system than the traditional method of partitioning a disk. LVM is used for easy resizing and moving partitions. With LVM you can create as many Logical Volumes as you need and you can also use LVM to take snapshots of your filesystem. However, unless you actually need any of these features, adding the extra layer of complexity doesn't provide any benefits. Source: https://unixsheikh.com/tutorials/real-full-disk-encryption-using-grub-on-void-linux-for-bios.html

# Open LUKS partition into /dev/mapper/<name>
echo $LUKS_PASSWORD | cryptsetup luksOpen $LUKS_PARTITION luks

# Create volume group on device
vgcreate $VOLUME_GROUP /dev/mapper/luks

# Ceate logical root volume in existing volume group
# Home and swap volumes can also be created, but I don't see a need for more than one partition at this time.
lvcreate --name root --size 100%FREE $VOLUME_GROUP

# Create root file system on logical volume root
mkfs.$FILE_SYSTEM --volume-label root /dev/$HOSTNAME/root

#
# MOUNT EFI AND ROOT PARTITIONS
#

# Mount EFI partition
mkdir -p /mnt/boot/efi
mount $EFI_PARTITION /mnt/boot/efi

# Mount root partition
mount /dev/$HOSTNAME/root /mnt

#
# INSTALL SYSTEM
#

# TODO: Find out if and why copying RSA keys is needed
# Copy the RSA keys from the installation medium to the target root directory:
# mkdir -p /mnt/var/db/xbps/keys
# cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

# Install Void base system to the root partition
echo y | xbps-install -SyR https://repo-default.voidlinux.org/current/$LIBC -r /mnt base-system lvm2 cryptsetup grub-x86_64-efi

#
# SETUP ROOT USER
#

# Change ownership and permissions of root directory
chroot /mnt chown root:root /
chroot /mnt chmod 755 /

#Use the "HereDoc" to send a sequence of commands into chroot, allowing the root and non-root user passwords in the chroot to be set non-interactively
cat << EOF | chroot /mnt
echo "$ROOT_PASSWOD\n$ROOT_PASSWORD" | passwd -q root
EOF

#
# SOME CONFIGUARTION
#

#Set hostname and language/locale
echo $HOSTNAME > /mnt/etc/hostname

if [[ -z $LIBC ]]; then
	echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
  echo "en_US.UTF-8 UTF-8" >> /mnt/etc/default/libc-locales
  xbps-reconfigure -fr /mnt/ glibc-locales
fi

#
# FSTAB CONFIGURATION
#

# TODO: Find out about tmpfs

# Find the UUID of the encrypted LUKS partition
luks_uuid=$(blkid -o value -s UUID $LUKS_PARTITION)

# Find the UUID of the encrypted LUKS partition
efi_uuid=$(blkid -o value -s UUID $EFI_PARTITION)

#Add lines to fstab, which determines which partitions/volumes are mounted at boot
echo -e "UUID=$LUKS_PARTITION	/	$FILE_SYSTEM	defaults	0	0" >> /mnt/etc/fstab
echo -e "UUID=$EFI_PARTITION	/boot/efi	vfat	defaults	0	0" >> /mnt/etc/fstab

#
# GRUB CONFIGURATION
#

# Modify GRUB config to allow for LUKS encryption.
echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub

kernel_params="rd.lvm.vg=$HOSTNAME rd.luks.uuid=$LUKS_UUID"
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$kernel_params /" /mnt/etc/default/grub

#
# AUTOMATICALLY UNLOCK ENCRYPTED DRIVE ON BOOT
#

# Generate keyfile
dd bs=1 count=64 if=/dev/urandom of=/mnt/boot/volume.key

# Add the key to the encrypted volume
cat << EOF | chroot /mnt
echo $LUKS_PASSWORD | cryptsetup -q luksAddKey $LUKS_PARTITION /boot/volume.key
EOF

# Change the permissions to protect generated the keyfile
chroot /mnt chmod 000 /boot/volume.key
chroot /mnt chmod -R g-rwx,o-rwx /boot

#Add keyfile to /etc/crypttab
echo "$HOSTNAME	$LUKS_PARTITION	/boot/volume.key	luks" >> /mnt/etc/crypttab

#Add keyfile and crypttab to initramfs
echo -e "install_items+=\" /boot/volume.key /etc/crypttab \"" > /mnt/etc/dracut.conf.d/10-crypt.conf

#
# COMPLETE SYSTEM INSTALLATION
#

# Install GRUB bootloader
chroot /mnt grub-install $DISK

# Ensure an initramfs is generated
xbps-reconfigure --force --all --rootdir /mnt/

#
# UNMOUNT
#

# Unmount root volume
umount -R /mnt

# Deactivate volume group
vgchange -an

# Close LUKS encrypted partition
cryptsetup luksClose $hostname	

echo "Install is complete, reboot."
