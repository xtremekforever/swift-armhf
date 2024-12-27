#!/bin/bash

set -e

SRC_ROOT=$(pwd)

CONTAINER_NAME=swift-armv7-sysroot
DISTRIBUTION_NAME=$1
DISTRIUBTION_VERSION=$2
SYSROOT=$3

if [ -z $SYSROOT ]; then
    SYSROOT=sysroot-$DISTRIBUTION_NAME-$DISTRIUBTION_VERSION
fi
SYSROOT=$(pwd)/$SYSROOT

DISTRIBUTION="$DISTRIBUTION_NAME:$DISTRIUBTION_VERSION"

case $DISTRIUBTION_VERSION in
    "focal")
        INSTALL_DEPS_CMD=" \
            apt-get update && \
            apt-get install -y \
                libc6-dev \
                libgcc-9-dev \
                libicu-dev \
                libstdc++-9-dev \
                libstdc++6 \
                linux-libc-dev \
                zlib1g-dev \
                libcurl4-openssl-dev \
                libxml2-dev \
                libsystemd-dev \
        "
        ;;
    "bullseye")
        RASPIOS_VERSION="2024-10-22"
        RASPIOS_URL=https://downloads.raspberrypi.com/raspios_oldstable_lite_armhf/images/raspios_oldstable_lite_armhf-2024-10-28
        INSTALL_DEPS_CMD=" \
            apt-get update && \
            apt-get install -y \
                libc6-dev \
                libgcc-10-dev \
                libicu-dev \
                libstdc++-10-dev \
                libstdc++6 \
                linux-libc-dev \
                zlib1g-dev \
                libcurl4-openssl-dev \
                libxml2-dev \
                libsystemd-dev \
        "
        ;;
    "jammy" | "bookworm")
        RASPIOS_VERSION="2024-11-19"
        RASPIOS_URL=https://downloads.raspberrypi.com/raspios_lite_armhf/images/raspios_lite_armhf-$RASPIOS_VERSION
        INSTALL_DEPS_CMD=" \
            apt-get update && \
            apt-get install -y \
                libc6-dev \
                libgcc-12-dev \
                libicu-dev \
                libstdc++-12-dev \
                libstdc++6 \
                linux-libc-dev \
                zlib1g-dev \
                libcurl4-openssl-dev \
                libxml2-dev \
                libsystemd-dev \
        "
        ;;
    "mantic" | "noble")
        INSTALL_DEPS_CMD=" \
            apt-get update && \
            apt-get install -y \
                libc6-dev \
                libgcc-13-dev \
                libicu-dev \
                libstdc++-13-dev \
                libstdc++6 \
                linux-libc-dev \
                zlib1g-dev \
                libcurl4-openssl-dev \
                libxml2-dev \
                libsystemd-dev \
        "
        ;;
    *)
        echo "Unsupported distribution $DISTRIBUTION!"
        echo "If you'd like to support it, update this script to add the apt package list for it."
        exit
        ;;
esac

if [[ $DISTRIBUTION_NAME = "raspios" ]]; then
    INSTALL_DEPS_CMD="$INSTALL_DEPS_CMD symlinks"
fi

if [ ! -z $EXTRA_PACKAGES ]; then
    echo "Including extra packages: $EXTRA_PACKAGES"
    INSTALL_DEPS_CMD="$INSTALL_DEPS_CMD && apt-get install -y $EXTRA_PACKAGES"
fi

# This is for supporting armv6
if [[ $DISTRIBUTION_NAME = "raspios" ]]; then
    echo "Installing host dependencies..."
    sudo apt update && sudo apt install qemu-user-static p7zip xz-utils

    mkdir artifacts && true
    cd artifacts

    echo "Downloading raspios $RASPBIAN_VERSION for $DISTRIUBTION_VERSION..."
    IMAGE_FILE=$RASPIOS_VERSION-raspios-$DISTRIUBTION_VERSION-armhf-lite.img
    DOWNLOAD_URL=$RASPIOS_URL/$IMAGE_FILE.xz
    wget -q -N $DOWNLOAD_URL

    echo "Uncompressing $IMAGE_FILE.gz and extracting contents..."
    xz -dk $IMAGE_FILE.xz && true
    7z e -y $IMAGE_FILE

    echo "Mounting 1.img to install additional dependencies..."
    rm -rf sysroot && mkdir sysroot
    sudo mount -o loop 1.img sysroot
    sudo mount --bind /dev sysroot/dev
    sudo mount --bind /dev/pts sysroot/dev/pts
    sudo mount --bind /proc sysroot/proc
    sudo mount --bind /sys sysroot/sys

    echo "Starting chroot to install dependencies..."
    sudo cp /usr/bin/qemu-arm-static sysroot/usr/bin
    REMOVE_DEPS_CMD="apt remove -y --purge \
        apparmor \
        linux-image* \
        *firmware* \
    "
    sudo chroot sysroot qemu-arm-static /bin/bash -c "$REMOVE_DEPS_CMD && $INSTALL_DEPS_CMD"

    echo "Copying files from sysroot to $SYSROOT..."
    rm -rf $SYSROOT
    mkdir -p $SYSROOT/usr
    sudo chroot sysroot qemu-arm-static /bin/bash -c "symlinks -cr /usr/lib"
    cp -r sysroot/lib $SYSROOT/lib
    cp -r sysroot/usr/lib $SYSROOT/usr/lib
    cp -r sysroot/usr/include $SYSROOT/usr/include

    echo "Umounting and cleaning up..."
    sudo umount -R sysroot
    rm *.fat
    rm *.img
else
    echo "Starting up qemu emulation"
    docker run --privileged --rm tonistiigi/binfmt --install all

    echo "Building $DISTRIUBTION distribution for sysroot"
    docker rm --force $CONTAINER_NAME
    docker run \
        --platform linux/armhf \
        --name $CONTAINER_NAME \
        $DISTRIUBTION \
        /bin/bash -c "$INSTALL_DEPS_CMD"

    echo "Extracting sysroot folders to $SYSROOT"
    rm -rf $SYSROOT
    mkdir -p $SYSROOT/usr
    docker cp $CONTAINER_NAME:/lib $SYSROOT/lib
    docker cp $CONTAINER_NAME:/usr/lib $SYSROOT/usr/lib
    docker cp $CONTAINER_NAME:/usr/include $SYSROOT/usr/include

    # Find broken links, re-copy
    cd $SYSROOT
    BROKEN_LINKS=$(find . -xtype l)
    while IFS= read -r link; do
        # Ignore empty links
        if [ -z "${link}" ]; then continue; fi

        echo "Replacing broken symlink: $link"
        link=$(echo $link | sed '0,/./ s/.//')
        docker cp -L $CONTAINER_NAME:$link $(dirname .$link)
    done <<< "$BROKEN_LINKS"

    echo "Cleaning up"
    docker rm $CONTAINER_NAME
fi
