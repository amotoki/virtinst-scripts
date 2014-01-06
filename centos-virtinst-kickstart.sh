#!/bin/bash

WORKDIR=`dirname $0`
source $WORKDIR/common.sh

if [ -z "$1" ]; then
  echo "Name must be specified!"
  echo "Usage: $0 NAME [RELEASE]"
  exit 1
fi

if [ -n "$2" ]; then
  RELEASE=$2
else
  RELEASE=6
fi

NAME=$1
DISK=$DISKIMG_DIR/$NAME.img
ARCH=x86_64
LOCATION=http://ftp.riken.jp/Linux/centos/$RELEASE/os/$ARCH/
PROXY=http://192.168.122.1:3128
KSFILE=/tmp/ks-$$.cfg

function create_image() {
  if [ ! -f $DISK ]; then
    qemu-img create -f qcow2 $DISK 20G
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
    --ram 1024 \
    --vcpus 1 \
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
