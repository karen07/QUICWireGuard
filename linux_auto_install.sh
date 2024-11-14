#!/bin/sh

if [ -f /usr/bin/apt ]; then
	sudo apt update && sudo apt-get install -y build-essential linux-headers-$(uname -r)
fi

if [ -f /usr/bin/pacman ]; then
	sudo pacman -S make wget base-devel linux-headers --noconfirm
fi

if [ ! -d linux ]; then
	git clone https://github.com/torvalds/linux.git
fi

KERNEL_VERSION=$(uname -r)
KERNEL_VERSION_GIT=v$(echo $KERNEL_VERSION | sed -r 's/^([0-9]+\.[0-9]+).*/\1/g')

cd linux

git checkout $KERNEL_VERSION_GIT

WIREGUARD_FOLDER=$(find . -type d | grep "/drivers/net/wireguard" | head -n 1)

cp ../QUICWireGuard.patch $WIREGUARD_FOLDER

cd $WIREGUARD_FOLDER

if [ ! -f QUICWireGuard_tmp ]; then
	patch -p1 <QUICWireGuard.patch
	touch QUICWireGuard_tmp
fi

make

if [ -f wireguard.ko ]; then
	WIREGUARD_MODULE_FOLDER=$(find /lib/modules/$KERNEL_VERSION -type d | grep "/drivers/net/wireguard")
	sudo rm -rf $WIREGUARD_MODULE_FOLDER/wireguard.ko*
	sudo cp wireguard.ko $WIREGUARD_MODULE_FOLDER
	sudo depmod
	echo "Command succeeded"
fi
