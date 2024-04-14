#!/bin/sh -x
#
# Author. Tim Molteno tim@molteno.net
# (C) 2022.
# http://www.orangepi.org/Docs/Makingabootable.html

# Make Image the first parameter of this script is the directory containing all the files needed
# This is done to allow the script to be run outside of Docker for testing.
OUTPORT="$1"


KERNEL_TAG="$(echo "${KERNEL_TAG}" | tr '/' '_')"
IMG_NAME="${BOARD}_gcc_${GNU_TOOLS_TAG}_kernel_${KERNEL_TAG}.img"
IMG="${OUTPORT}/${IMG_NAME}"
MKFS_COMMON_OPTS="-b 4096 -E stride=32,stripe_width=32,lazy_itable_init,lazy_journal_init,packed_meta_blocks=1,discard"

echo "Creating Blank Image ${IMG}"

truncate -s "${DISK_MB}M" "${IMG}"

# Setup Loopback device
LOOP="$(losetup -f --show "${IMG}" | cut -d'/' -f3)"
LOOPDEV="/dev/${LOOP}"
echo "Partitioning loopback device ${LOOPDEV}"


# dd if=/dev/zero of=${LOOPDEV} bs=1M count=200
parted -s -a optimal -- "${LOOPDEV}" mklabel gpt
parted -s -a optimal -- "${LOOPDEV}" mkpart boot ext2 40MiB 300MiB
parted -s -a optimal -- "${LOOPDEV}" mkpart root ext4 300MiB -1GiB
parted -s -a optimal -- "${LOOPDEV}" mkpart swap linux-swap -1GiB 100%

kpartx -av "${LOOPDEV}"

# shellcheck disable=SC2086
mkfs.ext2 -L lichee_rv_boot ${MKFS_COMMON_OPTS} "/dev/mapper/${LOOP}p1"
# shellcheck disable=SC2086
mkfs.ext4 -L lichee_rv_root ${MKFS_COMMON_OPTS} "/dev/mapper/${LOOP}p2"
mkswap "/dev/mapper/${LOOP}p3"

# Burn U-boot
echo "Burning u-boot to ${LOOPDEV}"

# Copy files https://linux-sunxi.org/Allwinner_Nezha
dd if=/builder/u-boot-sunxi-with-spl.bin "of=${LOOPDEV}" bs=1024 seek=128

# Copy Files, first the boot partition
echo "Mounting  partitions ${LOOPDEV}"
BOOTPOINT=/sdcard_boot

mkdir -p "${BOOTPOINT}"
mount "/dev/mapper/${LOOP}p1" "${BOOTPOINT}"

# Boot partition
cp /builder/Image.gz "${BOOTPOINT}/"

# install U-Boot
cp /builder/boot.scr "${BOOTPOINT}/"
cp /builder/ov_lichee_rv_mini_lcd.dtb "${BOOTPOINT}/"

umount "${BOOTPOINT}"
rm -rf "${BOOTPOINT}"


# Now create the root partition
MNTPOINT=/sdcard_rootfs
mkdir -p "${MNTPOINT}"
mount "/dev/mapper/${LOOP}p2" -o discard,noatime "${MNTPOINT}"

# Copy the rootfs
cp -a /builder/rv64-port/* "${MNTPOINT}"

# Set up the rootfs
cp /usr/bin/qemu-riscv64-static "${MNTPOINT}/usr/bin/"
chroot "${MNTPOINT}" qemu-riscv64-static /bin/sh /setup_rootfs.sh
rm "${MNTPOINT}/setup_rootfs.sh" "${MNTPOINT}/usr/bin/qemu-riscv64-static"

# Set up fstab
cat >> "${MNTPOINT}/etc/fstab" <<EOF
# <device>        <dir>        <type>        <options>            <dump> <pass>
/dev/mmcblk0p1    /boot        ext2          rw,defaults,noatime,discard  1      1
/dev/mmcblk0p2    /            ext4          rw,defaults,noatime,discard  1      1
/dev/mmcblk0p3    none         swap          sw,discard                   0      0
EOF

# Clean Up
echo "Cleaning Up..."
fstrim --verbose "${MNTPOINT}"
umount "${MNTPOINT}"
rm -rf "${MNTPOINT}"

kpartx -d "${LOOPDEV}"
losetup -d "${LOOPDEV}"

# Now compress the image
#echo "Compressing the image: ${IMG}"

#(cd "${OUTPORT}" && xz -T0 "${IMG}")
