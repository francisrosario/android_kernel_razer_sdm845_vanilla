#!/bin/bash
export KERNELDIR=`readlink -f .`
export RAMFS_SOURCE=`readlink -f $KERNELDIR/ramdisk`
export PARTITION_SIZE=67108864

export OS="9.0.0"
export SPL="2019-09"

echo "kerneldir = $KERNELDIR"
echo "ramfs_source = $RAMFS_SOURCE"

RAMFS_TMP="/tmp/TrinityKernel-aura-ramdisk"

echo "ramfs_tmp = $RAMFS_TMP"
cd $KERNELDIR


echo "Compiling kernel and cleaning."
rm -rf out
mkdir out
make clean
make mrproper
make O=out clean
make O=out mrproper
echo "Sleeping for 3 Seconds."
sleep 3s
#cp defconfig .config
export ARCH=arm64
export SUBARCH=arm64
export DTC_EXT=dtc
make O=out cheryl2-perf_defconfig
make O=out -j8 

echo "Building new ramdisk"
#remove previous ramfs files
rm -rf '$RAMFS_TMP'*
rm -rf $RAMFS_TMP
rm -rf $RAMFS_TMP.cpio
#copy ramfs files to tmp directory
cp -axpP $RAMFS_SOURCE $RAMFS_TMP
cd $RAMFS_TMP

#clear git repositories in ramfs
find . -name .git -exec rm -rf {} \;
find . -name EMPTY_DIRECTORY -exec rm -rf {} \;

sed -i -e s@ro.build.version.release.*@ro.build.version.release=${OS}@g \
       -e s@ro.build.version.security_patch.*@ro.build.version.security_patch=${SPL}-01@g prop.default

if [[ "$stock" == "1" ]] ; then
	# Don't use Magisk
	mv .backup/init init
	rm -rf .backup
fi

$KERNELDIR/ramdisk_fix_permissions.sh 2>/dev/null

cd $KERNELDIR
rm -rf $RAMFS_TMP/tmp/*

cd $RAMFS_TMP
find . | fakeroot cpio -H newc -o | lz4 -l -9 > $RAMFS_TMP.cpio.lz4
ls -lh $RAMFS_TMP.cpio.lz4
cd $KERNELDIR

echo "Making new boot image"
./mkbootimg \
    --kernel $KERNELDIR/out/arch/arm64/boot/Image.gz-dtb \
    --ramdisk $RAMFS_TMP.cpio.lz4 \
    --cmdline 'console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0xA84000 androidboot.hardware=qcom androidboot.console=ttyMSM0 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 ehci-hcd.park=3 lpm_levels.sleep_disabled=1 service_locator.enable=1 swiotlb=2048 androidboot.configfs=true firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7 androidboot.usbcontroller=a600000.dwc3 buildvariant=user printk.devkmsg=on' \
    --base           0x00000000 \
    --pagesize       4096 \
    --kernel_offset  0x00008000 \
    --ramdisk_offset 0x01000000 \
    --second_offset  0x00f00000 \
    --tags_offset    0x00000100 \
    --os_version     $OS \
    --os_patch_level $SPL \
    --header_version 1 \
    -o $KERNELDIR/boot.img

GENERATED_SIZE=$(stat -c %s boot.img)
if [[ $GENERATED_SIZE -gt $PARTITION_SIZE ]]; then
	echo "boot.img size larger than partition size!" 1>&2
	exit 1
fi

echo "done"
ls -al boot.img
echo ""
