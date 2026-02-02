#!/bin/sh

pwd_var=$(pwd)

if [ -z "$1" ]; then
    echo "Argument 1: Empty router ssh name"
    exit 1
fi

if [ -f /usr/bin/apt ]; then
    sudo apt update
    sudo apt install -y \
        build-essential \
        libncurses-dev \
        git \
        rsync \
        swig \
        unzip \
        zstd \
        wget
fi

if [ -f /usr/bin/pacman ]; then
    sudo pacman -Sy --noconfirm \
        base-devel \
        python \
        python-setuptools \
        git \
        rsync \
        swig \
        unzip \
        zstd \
        wget
fi

ROUTER_NAME="$1"

if ! ssh -o StrictHostKeyChecking=no "$ROUTER_NAME" cat /etc/os-release; then
    echo "SSH connection or remote command failed"
    exit 1
fi

ROUTER_KERNEL="$(ssh "$ROUTER_NAME" uname -r)"
ROUTER_OS_RELEASE="$(ssh "$ROUTER_NAME" cat /etc/os-release)"

if [ -z "$2" ]; then
    VERSION=$(echo "$ROUTER_OS_RELEASE" \
        | grep VERSION | head -n 1 | cut -d '"' -f2)
else
    VERSION="$2"
fi

BOARD=$(echo "$ROUTER_OS_RELEASE" \
    | grep OPENWRT_BOARD | head -n 1 | cut -d '"' -f2)

OPENWRT_DL="https://downloads.openwrt.org/releases"
CONFIGBUILDINFO_URL="$OPENWRT_DL/$VERSION/targets/$BOARD/config.buildinfo"

build_dir="$pwd_var/build_${1}_${VERSION}"
build_name="build_${1}_${VERSION}"

if [ ! -d "$build_dir" ]; then
    git clone https://github.com/openwrt/openwrt.git "$build_name"
fi

cd "$build_dir" || exit

if ! git checkout "v$VERSION"; then
    echo "git checkout v$VERSION failed"
    exit 1
fi

if ! wget "$CONFIGBUILDINFO_URL" -O .config; then
    echo "wget failed: $CONFIGBUILDINFO_URL"
    exit 1
fi

./scripts/feeds update -a
./scripts/feeds install -a

make defconfig

make -j"$(nproc)" download
make -j"$(nproc)" tools/compile
make -j"$(nproc)" toolchain/compile
make -j"$(nproc)" target/linux/compile

WIREGUARD_FOLDER=$(
    find "$build_dir" -type d \
        | grep "/drivers/net/wireguard" \
        | grep target \
        | head -n 1
)

cp "$pwd_var/QUICWireGuard.patch" \
    "$WIREGUARD_FOLDER/QUICWireGuard.patch"

cd "$WIREGUARD_FOLDER" || exit

if [ ! -f QUICWireGuard_tmp ]; then
    patch -p1 <QUICWireGuard.patch
    touch QUICWireGuard_tmp
fi

cd "$build_dir" || exit

make -j"$(nproc)" target/linux/compile

if [ -f "$WIREGUARD_FOLDER/wireguard.ko" ]; then
    if [ -z "$2" ]; then
        dst_dir="/lib/modules/$ROUTER_KERNEL"
        scp -O "$WIREGUARD_FOLDER/wireguard.ko" "$ROUTER_NAME:$dst_dir/"
        echo "Command succeeded"
    else
        out_ko="$pwd_var/wireguard_${1}_${VERSION}.ko"
        cp "$WIREGUARD_FOLDER/wireguard.ko" "$out_ko"
    fi
fi
