#!/bin/bash

# Build system.
#
# (C) 2019.11.08 BiscuitOS <buddy.zhang@aliyun.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.

QEMUT=./qemu-system-aarch64
ARCH=arm64
OUTPUT=.
ROOTFS_NAME=ext4
CROSS_COMPILE=aarch64-linux-gnu
FS_TYPE=ext4
FS_TYPE_TOOLS=mkfs.ext4
ROOTFS_SIZE=1800
RAM_SIZE=512
CMDLINE="earlycon root=/dev/vda rw rootfstype=${FS_TYPE} console=ttyAMA0 init=/linuxrc loglevel=8"

do_running()
{
	SUPPORT_DEBUG=N
	SUPPORT_NET=N
	[ ${1}X = "debug"X -o ${2}X = "debug"X ] && ARGS+="-s -S "
	if [ ${1}X = "net"X  -o ${2}X = "net"X ]; then
		ARGS+="-net tap "
		ARGS+="-device virtio-net-device,netdev=bsnet0,"
		ARGS+="mac=E0:FE:D0:3C:2E:EE "
		ARGS+="-netdev tap,id=bsnet0,ifname=bsTap0 "
	fi
	

	sudo ${QEMUT} ${ARGS} \
	-M virt \
	-m ${RAM_SIZE}M \
	-cpu cortex-a53 \
	-smp 2 \
	-kernel Image \
	-fsdev local,id=r,path=/home,security_model=none \
	-device virtio-9p-device,fsdev=r,mount_tag=r \
	-device virtio-blk-device,drive=hd0 \
	-drive if=none,file=BiscuitOS.img,format=raw,id=hd0 \
	-serial stdio \
	-nographic \
	-nodefaults \
	-append "${CMDLINE}"
}


do_package()
{
	cp BiscuitOS.img BiscuitOS.img_back
	dd if=/dev/zero of=${OUTPUT}/rootfs/ramdisk bs=1M count=${ROOTFS_SIZE}
	${FS_TYPE_TOOLS} -F ${OUTPUT}/rootfs/ramdisk
	mkdir -p ${OUTPUT}/rootfs/tmpfs
	sudo mount -t ${FS_TYPE} ${OUTPUT}/rootfs/ramdisk \
	              ${OUTPUT}/rootfs/tmpfs/ -o loop
	sudo cp -raf ${OUTPUT}/rootfs/${ROOTFS_NAME}/*  ${OUTPUT}/rootfs/tmpfs/
	sync
	sudo umount ${OUTPUT}/rootfs/tmpfs
	mv ${OUTPUT}/rootfs/ramdisk ${OUTPUT}/BiscuitOS.img
	rm -rf ${OUTPUT}/rootfs/tmpfs
}

# Lunching BiscuitOS
case $1 in
	"pack")
		# Package BiscuitOS.img
		do_package
		;;
	"debug")
		# Debugging BiscuitOS
		do_running debug
		;;
	"net")
		# Establish Netwroking
		sudo ${NET_CFG}/bridge.sh
		sudo cp -rf ${NET_CFG}/qemu-ifup /etc
		sudo cp -rf ${NET_CFG}/qemu-ifdown /etc
		do_running net
		;;
	*)
		# Default Running BiscuitOS
		do_running $1 $2
		;;
esac
