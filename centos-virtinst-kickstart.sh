#!/bin/bash -e

WORKDIR=`dirname $0`
CONFIG_FILE=$WORKDIR/config.sh
[ -f $CONFIG_FILE ] && source $CONFIG_FILE

DISKIMG_DIR=${DISKIMG_DIR:-$HOME/images}
SITE=${CENTOS_SITE:-http://ftp.riken.jp/Linux/centos}
PROXY=${CENTOS_PROXY:-${PROXY:-$http_proxy}}

ARCH=x86_64
NUM_CPU=1
MEMORY=4096
DISKSIZE=20G
DISKFORMAT=qcow2

function usage() {
  cat <<EOF
Usage: $0 [options] NAME [RELEASE]

Options:
  -a ARCH       : VM architecture: x86_64, i386 (default: $ARCH)
  -c NUM_CPU    : VM number of CPU (default: $NUM_CPU)
  -m MEMORY     : VM memory size [MB] (default: $MEMORY)
  -f DISKFORMAT : QEMU image format: qcow2, raw (default: $DISKFORMAT)
  -s DISKSIZE   : QEMU image size, e.g., 50G (default: $DISKSIZE)
  -p PASSWORD   : Password for root user (default: NAME)

Configurations:
  DISKIMG_DIR=$DISKIMG_DIR
  CENTOS_SITE=$SITE
  CENTOS_PROXY=$PROXY
EOF
  exit 1
}

while getopts "a:c:m:f:s:p:h" OPT; do
    case $OPT in
        a) ARCH=$OPTARG
           if [ "$ARCH" != "i386" -a "$ARCH" != "x86_64" ]; then
               echo "Arch must be either x86_64 or i386."
               exit 1
           fi
           ;;
        c) NUM_CPU=$OPTARG; ;;
        m) MEMORY=$OPTARG; ;;
        f) DISKFORMAT=$OPTARG
           if [ "$DISKFORMAT" != "qcow2" -a "$DISKFORMAT" != "raw" ]; then
               echo "Disk format must be either qcow2 or raw."
               exit 1
           fi
           ;;
        s) DISKSIZE=$OPTARG; ;;
        p) PASSWORD=$OPTARG; ;;
        ?) usage
            ;;
    esac
done
shift `expr $OPTIND - 1`

if [ -z "$1" ]; then
  echo "Name must be specified!"
  usage
fi

if [ -n "$2" ]; then
  RELEASE=$2
else
  RELEASE=6
fi

NAME=$1
DISK=$DISKIMG_DIR/$NAME.img
LOCATION=$SITE/$RELEASE/os/$ARCH
KSFILE=/tmp/ks-$$.cfg

if [ -z "$PASSWORD" ]; then
  PASSWORD=$NAME
fi

function create_image() {
  if [ ! -f $DISK ]; then
    qemu-img create -f $DISKFORMAT $DISK $DISKSIZE
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

rootpw --plaintext $PASSWORD
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
    --disk $DISK,format=$DISKFORMAT,bus=virtio \
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
