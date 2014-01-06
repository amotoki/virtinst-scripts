#!/bin/bash

SUPPORTED="(lucid|oneiric|precise|quantal|raring|saucy|trusty)"
ARCH=amd64
SITE=http://ftp.riken.go.jp/Linux/ubuntu
#SITE=http://ftp.jaist.ac.jp/pub/Linux/ubuntu
PROXY=http://192.168.122.1:8000

NUM_CPU=4
MEMORY=8192

WORKDIR=`dirname $0`
source $WORKDIR/common.sh

if [ -n "$PROXY" ]; then
    export http_proxy=$PROXY
    export https_proxy=$PROXY
fi

if [ -z "$1" ]; then
    echo "Name must be specified!"
    echo "Usage: $0 NAME RELEASE [i386|amd64]"
    exit 1
fi

if [ -z "$2" ]; then
    echo "release must be specified! $SUPPORTED"
    echo "Usage: $0 NAME RELEASE [i386|amd64]"
    exit 1
fi

if [ -n "$3" ]; then
    if [ "$3" == "i386" -o "$3" == "amd64" ]; then
        ARCH=$3
    else
        echo "Arch must be either amd64 or i386."
        exit 1
    fi
fi

NAME=$1
DISK=$DISKIMG_DIR/$NAME.img

DIST=$2
if [[ ! "$DIST" =~ $SUPPORTED ]]; then
    echo "Release '$DIST' is not supported."
    echo "$SUPPORTED must be specified"
    exit 2
fi

if [ "$ARCH" == "amd64" ]; then
    VIRT_ARCH=x86_64
else
    VIRT_ARCH=i386
fi
case "$DIST" in
  lucid)
    DIST_VER=10.04.4
    ;;
  precise)
    DIST_VER=12.04.3
    ;;
  quantal)
    DIST_VER=12.10
    ;;
  raring)
    DIST_VER=13.04
    ;;
  saucy)
    DIST_VER=13.10
    ;;
esac

LOCATION=$SITE/dists/$DIST/main/installer-$ARCH/
if [ -n "$DIST_VER" ]; then
    ISO_LOCATION=$ISO_DIR/ubuntu-${DIST_VER}-server-${ARCH}.iso
    if [ -f $ISO_LOCATION ]; then
        LOCATION=$ISO_LOCATION
    fi
fi

if [ ! -f $DISK ]; then
    qemu-img create -f qcow2 $DISK 20G
fi

sudo virt-install \
    --name $NAME \
    --os-type linux \
    --os-variant ubuntu${DIST} \
    --virt-type kvm \
    --connect=qemu:///system \
    --vcpus $NUM_CPU \
    --ram $MEMORY \
    --arch $VIRT_ARCH \
    --serial pty \
    --console pty \
    --disk=$DISK,format=qcow2,bus=virtio \
    --nographics \
    --location $LOCATION \
    --extra-args "console=ttyS0,115200" \
    --network network=default,model=virtio
