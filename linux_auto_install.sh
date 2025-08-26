#!/bin/sh

if [ -f /usr/bin/apt ]; then
    sudo apt update
    sudo apt install -y build-essential "linux-headers-$(uname -r)"
fi

if [ -f /usr/bin/pacman ]; then
    sudo pacman -Sy --noconfirm base-devel linux-headers wget
fi

KERNEL_VERSION=$(uname -r)
KERNEL_VERSION_GIT=$(echo "$KERNEL_VERSION" | sed -r 's/^([0-9]+\.[0-9]+).*/\1/g')

if [ ! -f "v${KERNEL_VERSION_GIT}.tar.gz" ]; then
    wget "https://github.com/torvalds/linux/archive/refs/tags/v${KERNEL_VERSION_GIT}.tar.gz"
fi

if [ ! -d "linux-${KERNEL_VERSION_GIT}" ]; then
    tar -xf "v${KERNEL_VERSION_GIT}.tar.gz"
fi

cd "linux-${KERNEL_VERSION_GIT}" || exit

WIREGUARD_FOLDER=$(find . -type d | grep "/drivers/net/wireguard" | head -n 1)

cp ../QUICWireGuard.patch "$WIREGUARD_FOLDER"

cd "$WIREGUARD_FOLDER" || exit

if [ ! -f QUICWireGuard_tmp ]; then
    patch -p1 <QUICWireGuard.patch
    touch QUICWireGuard_tmp
fi

make

if [ -f wireguard.ko ]; then
    WIREGUARD_MODULE_FOLDER=$(find "/lib/modules/$KERNEL_VERSION" -type d | grep "/drivers/net/wireguard")
    sudo rm -rf "$WIREGUARD_MODULE_FOLDER"/wireguard.ko*
    sudo cp wireguard.ko "$WIREGUARD_MODULE_FOLDER"
    sudo depmod
    echo "Command succeeded"
fi
