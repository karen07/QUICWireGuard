#!/bin/sh

if [ -f /usr/bin/apt ]; then
    sudo apt update
    sudo apt install -y build-essential "linux-headers-$(uname -r)"
fi

if [ -f /usr/bin/pacman ]; then
    sudo pacman -Sy --noconfirm base-devel linux-headers wget
fi

KERNEL_VERSION=$(uname -r)
KERNEL_VERSION_GIT=$(echo "$KERNEL_VERSION" | awk -F. '{print $1 "." $2}')

TARBALL="v${KERNEL_VERSION_GIT}.tar.gz"
SRC_DIR="linux-${KERNEL_VERSION_GIT}"
URL_BASE="https://github.com/torvalds/linux/archive/refs/tags"
URL_TARBALL="$URL_BASE/$TARBALL"

if [ ! -f "$TARBALL" ]; then
    wget "$URL_TARBALL"
fi

if [ ! -d "$SRC_DIR" ]; then
    tar -xf "$TARBALL"
fi

cd "$SRC_DIR" || exit

WIREGUARD_FOLDER=$(find . -type d | grep "/drivers/net/wireguard" | head -n 1)

cp ../QUICWireGuard.patch "$WIREGUARD_FOLDER"

cd "$WIREGUARD_FOLDER" || exit

if [ ! -f QUICWireGuard_tmp ]; then
    patch -p1 <QUICWireGuard.patch
    touch QUICWireGuard_tmp
fi

make

if [ -f wireguard.ko ]; then
    MOD_ROOT="/lib/modules/$KERNEL_VERSION"
    MOD_DIR=$(find "$MOD_ROOT" -type d | grep "/drivers/net/wireguard")

    sudo rm -rf "$MOD_DIR"/wireguard.ko*
    sudo cp wireguard.ko "$MOD_DIR"
    sudo depmod
    echo "Command succeeded"
fi
