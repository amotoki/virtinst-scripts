#!/bin/bash -ex

WORKDIR=`dirname $0`
source $WORKDIR/config-common.sh
source $WORKDIR/config-centos.sh

DISKIMG_DIR=${DISKIMG_DIR:-$HOME/images}
SITE=${SITE:-http://ftp.riken.jp/Linux/centos}
PROXY=${PROXY:-}

NUM_CPU=${NUM_CPU:-1}
MEMORY=${MEMORY:-1024}
DISKSIZE=${DISKSIZE:-20G}

if [ -z "$1" ]; then
  echo "Name must be specified!"
  echo "Usage: $0 NAME [RELEASE [ARCH]]"
  exit 1
fi

if [ -n "$2" ]; then
  RELEASE=$2
else
  RELEASE=6
fi

ARCH=x86_64
if [ -n "$3" ]; then
    if [ "$3" == "i386" -o "$3" == "x86_64" ]; then
        ARCH=$3
    else
        echo "Arch must be either amd64 or i386."
        exit 1
    fi
fi

NAME=$1
DISK=$DISKIMG_DIR/$NAME.img
LOCATION=$SITE/$RELEASE/os/$ARCH/
KSFILE=/tmp/ks-$$.cfg

function create_image() {
  if [ ! -f $DISK ]; then
    qemu-img create -f qcow2 $DISK $DISKSIZE
  else
    echo "$DISK already exists. Please remove it first."
    exit 1
  fi
}

function generate_kickstart_config() {
  local url
  echo "url: $LOCATION"
  url="--url=$LOCATION"
  if [ -n "$PROXY" ]; then
    url+=" --proxy=$PROXY"
  fi

  cat > $KSFILE <<EOF
cmdline
install
url $url
lang en_US.UTF-8
keyboard jp106

network --device eth0 --onboot yes --bootproto dhcp --noipv6 --hostname $NAME

zerombr
bootloader --location=mbr --append="crashkernel=auto rhgb quiet"

clearpart --all --initlabel
part / --fstype=ext4 --grow --asprimary --size=1

rootpw --plaintext $NAME
authconfig --enableshadow --passalgo=sha512
selinux --disabled
firewall --disabled
firstboot --disabled
timezone --utc Asia/Tokyo
reboot

%packages
@core
@base
@japanese-support
%end
EOF
}

function virt_install() {
  sudo virt-install \
    --name $NAME \
    --virt-type kvm \
    --ram $MEMORY \
    --vcpus $NUM_CPU \
    --arch $ARCH \
    --os-type linux \
    --os-variant rhel6 \
    --boot hd \
    --disk $DISK,format=qcow2,bus=virtio \
    --network network=default,model=virtio \
    --serial pty \
    --console pty \
    --location $LOCATION \
    --initrd-inject $KSFILE \
    --extra-args "ks=file:/`basename $KSFILE` console=ttyS0,115200" \
    --nographics

    #--graphics vnc \
    #--noautoconsole \

    #--network bridge=br0 \
}

function cleanup() {
  rm -v $KSFILE
}

create_image
generate_kickstart_config
virt_install
cleanup
