#!/bin/sh

pwd_var=$(pwd)

if [ -z "$1" ]; then
    echo "Argument 1: Empty router ssh name"
    exit 1
fi

if [ -f /usr/bin/apt ]; then
    sudo apt update
    sudo apt install -y build-essential libncurses-dev git rsync swig unzip zstd wget
fi

if [ -f /usr/bin/pacman ]; then
    sudo pacman -Sy --noconfirm base-devel python python-setuptools git rsync swig unzip zstd wget
fi

ROUTER_NAME="$1"

if ! ssh -o StrictHostKeyChecking=no "$ROUTER_NAME" cat /etc/os-release; then
    echo "SSH connection or remote command failed"
    exit 1
fi

ROUTER_KERNEL="$(ssh "$ROUTER_NAME" uname -r)"
ROUTER_OS_RELEASE="$(ssh "$ROUTER_NAME" cat /etc/os-release)"
VERSION=$(echo "$ROUTER_OS_RELEASE" | grep VERSION | head -n 1 | cut -d '"' -f2)
BOARD=$(echo "$ROUTER_OS_RELEASE" | grep OPENWRT_BOARD | head -n 1 | cut -d '"' -f2)
CONFIGBUILDINFO_URL="https://downloads.openwrt.org/releases/$VERSION/targets/$BOARD/config.buildinfo"

if [ ! -d "$pwd_var/openwrt" ]; then
    git clone https://git.openwrt.org/openwrt/openwrt.git
fi

cd "$pwd_var/openwrt" || exit
git checkout "v$VERSION"

wget "$CONFIGBUILDINFO_URL" -O .config

./scripts/feeds update -a
./scripts/feeds install -a

make defconfig

make -j"$(nproc)" download
make -j"$(nproc)" tools/compile
make -j"$(nproc)" toolchain/compile
make -j"$(nproc)" target/linux/compile

WIREGUARD_FOLDER=$(find "$pwd_var/openwrt" -type d | grep "/drivers/net/wireguard" | grep target | head -n 1)

cp "$pwd_var/QUICWireGuard.patch" "$WIREGUARD_FOLDER/QUICWireGuard.patch"

cd "$WIREGUARD_FOLDER" || exit

if [ ! -f QUICWireGuard_tmp ]; then
    patch -p1 <QUICWireGuard.patch
    touch QUICWireGuard_tmp
fi

cd "$pwd_var/openwrt" || exit

make -j"$(nproc)" target/linux/compile

if [ -f "$WIREGUARD_FOLDER/wireguard.ko" ]; then
    scp -O "$WIREGUARD_FOLDER/wireguard.ko" "$ROUTER_NAME:/lib/modules/$ROUTER_KERNEL/"
    echo "Command succeeded"
fi
