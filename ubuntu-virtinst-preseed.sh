#!/bin/bash -e

WORKDIR=`dirname $0`
CONFIG_FILE=$WORKDIR/config.sh
[ -f $CONFIG_FILE ] && source $CONFIG_FILE

SUPPORTED="(lucid|precise|saucy|trusty|utopic|vivid)"
ARCH=amd64

SITE=${UBUNTU_SITE:-http://ftp.riken.go.jp/Linux/ubuntu}
PROXY=${UBUNTU_PROXY:-${PROXY:-$http_proxy}}
DISKIMG_DIR=${DISKIMG_DIR:-$HOME/images}
ISO_DIR=${UBUNTU_ISO_DIR:-$HOME/iso/ubuntu}

USERNAME=ubuntu
# Unless password is specified NAME is used for password by default
PASSWORD=
NUM_CPU=1
MEMORY=4096
DISKSIZE=20G
DISKFORMAT=qcow2

# You can use the following keyword
# %ISO_DIR%
# %ARCH%
# %RELEASE_NAME% : precise, quantal, ....
# %RELEASE_VERSION% : 12.04, 12.10, ....
# %RELEASE_FULLVER% (including minor version for LTS) : 12.04.3, 10.04.4
ISO_LOCATION_FORMAT_DEFAULT=%ISO_DIR%/ubuntu-%RELEASE_FULLVER%-server-%ARCH%.iso
ISO_LOCATION_FORMAT=${UBUNTU_ISO_LOCATION_FORMAT:-$ISO_LOCATION_FORMAT_DEFAULT}

function usage() {
    cat <<EOF
Usage: $0 [options] NAME RELEASE

Options:
  -a ARCH       : VM architecture: x86_64, i386 (default: $ARCH)
  -c NUM_CPU    : VM number of CPU (default: $NUM_CPU)
  -m MEMORY     : VM memory size [MB] (default: $MEMORY)
  -f DISKFORMAT : QEMU image format: qcow2, raw (default: $DISKFORMAT)
  -s DISKSIZE   : QEMU image size, e.g., 50G (default: $DISKSIZE)
  -u USERNAME   : Username of the default user (default: $USERNAME)
  -p PASSWORD   : Password for the default user (default: $PASSWORD)
  -P            : Do not use preseed.cfg

Configurations:
  DISKIMG_DIR=$DISKIMG_DIR
  UBUNTU_SITE=$SITE
  UBUNTU_PROXY=$PROXY
  UBUNTU_ISO_DIR=$ISO_DIR
  UBUNTU_ISO_LOCATION_FORMAT=$ISO_LOCATION_FORMAT
EOF
    exit 1
}

while getopts "a:c:m:f:s:u:p:Ph" OPT; do
    case $OPT in
        a) ARCH=$OPTARG
           if [ "$ARCH" != "i386" -a "$ARCH" != "amd64" ]; then
               echo "Arch must be either amd64 or i386."
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
        u) USERNAME=$OPTARG; ;;
        p) PASSWORD=$OPTARG; ;;
        P) NO_PRESEED=true; ;;
        ?) usage
           ;;
    esac
done
shift `expr $OPTIND - 1`

if [ -z "$1" ]; then
    echo "Name must be specified!"
    usage
    exit 1
fi

if [ -z "$2" ]; then
    echo "release must be specified! $SUPPORTED"
    echo "Usage: $0 [options] NAME RELEASE"
    exit 1
fi

NAME=$1
DISK=$DISKIMG_DIR/$NAME.img

if [ -z "$PASSWORD" ]; then
    PASSWORD=$NAME
fi

RELEASE_NAME=$2
if [[ ! "$RELEASE_NAME" =~ $SUPPORTED ]]; then
    echo "Release '$RELEASE_NAME' is not supported."
    echo "$SUPPORTED must be specified"
    exit 2
fi

if [ "$ARCH" == "amd64" ]; then
    VIRT_ARCH=x86_64
else
    VIRT_ARCH=i386
fi
case "$RELEASE_NAME" in
  lucid)
    RELEASE_FULLVER=10.04.4
    ;;
  precise)
    RELEASE_FULLVER=12.04.3
    ;;
  saucy)
    RELEASE_FULLVER=13.10
    ;;
  trusty)
    RELEASE_FULLVER=14.04.01
    ;;
  utopic)
    RELEASE_FULLVER=14.10
    ;;
  vivid)
    RELEASE_FULLVER=15.04
    OS_VARIANT=ubuntuutopic
    ;;
esac
if [ -z "$OS_VARIANT" ]; then
  OS_VARIANT=ubuntu${RELEASE_NAME}
fi

LOCATION=$SITE/dists/$RELEASE_NAME/main/installer-$ARCH/
if [ -n "$RELEASE_FULLVER" ]; then
    RELEASE_VERSION=`echo $RELEASE_FULLVER | cut -d . -f 1-2`
    ISO_LOCATION=`echo $ISO_LOCATION_FORMAT | sed \
                      -e "s|%ISO_DIR%|$ISO_DIR|g" \
                      -e "s|%ARCH%|$ARCH|g" \
                      -e "s|%RELEASE_NAME%|$RELEASE_NAME|g" \
                      -e "s|%RELEASE_VERSION%|$RELEASE_VERSION|g" \
                      -e "s|%RELEASE_FULLVER%|$RELEASE_FULLVER|g" \
                 `
    if [ -f $ISO_LOCATION ]; then
        LOCATION=$ISO_LOCATION
    fi
fi

function generate_preseed_cfg() {
    PRESEED_DIR=/tmp/preseed$$
    PRESEED_BASENAME=preseed.cfg
    PRESEED_FILE=$PRESEED_DIR/$PRESEED_BASENAME
    mkdir -p $PRESEED_DIR
    cat > $PRESEED_FILE <<EOF
d-i debian-installer/language string en
d-i debian-installer/locale string en_US.UTF-8
d-i debian-installer/country string JP

d-i console-setup/ask_detect boolean false
d-i console-setup/layoutcode string jp

d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string $NAME
d-i netcfg/get_domain string localdomain
d-i netcfg/wireless_wep string

d-i mirror/country string JP
d-i mirror/http/hostname string jp.archive.ubuntu.com
d-i mirror/http/directory string /ubuntu
d-i mirror/http/proxy string $PROXY
d-i mirror/http/mirror select jp.archive.ubuntu.com

d-i clock-setup/utc boolean true
d-i time/zone string Asia/Tokyo
d-i clock-setup/ntp boolean true
d-i clock-setup/ntp-server string ntp.nict.jp

d-i partman-auto/method string lvm
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto-lvm/guided_size string max
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select Finish partitioning and write changes to disk
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

d-i passwd/user-fullname string $USERNAME
d-i passwd/username string $USERNAME
d-i passwd/user-password password $PASSWORD
d-i passwd/user-password-again password $PASSWORD
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false

#tasksel tasksel/first multiselect
tasksel tasksel/first multiselect standard
d-i pkgsel/include string openssh-server build-essential acpid git-core
d-i pkgsel/upgrade select none
d-i pkgsel/update-policy select none

d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true

d-i finish-install/reboot_in_progress note
EOF
}

function cleanup_preseed_cfg() {
    rm -v -f $PRESEED_FILE
    rmdir -v $PRESEED_DIR
}

function create_disk() {
    if [ ! -f $DISK ]; then
        qemu-img create -f $DISKFORMAT $DISK $DISKSIZE
    fi
}

function virtinst_with_preseed() {
    sudo virt-install \
        --name $NAME \
        --os-type linux \
        --os-variant $OS_VARIANT \
        --virt-type kvm \
        --connect=qemu:///system \
        --vcpus $NUM_CPU \
        --ram $MEMORY \
        --arch $VIRT_ARCH \
        --serial pty \
        --console pty \
        --disk=$DISK,format=$DISKFORMAT,bus=virtio \
        --nographics \
        --location $LOCATION \
        --initrd-inject $PRESEED_FILE \
        --extra-args "
    console=ttyS0,115200
    file=/$PRESEED_BASENAME
    auto=true
    priority=critical
    interface=auto
    language=en
    country=JP
    locale=en_US.UTF-8
    console-setup/layoutcode=jp
    console-setup/ask_detect=false
    " \
        --network network=default,model=virtio
}

function virtinst_without_preseed() {
    sudo virt-install \
        --name $NAME \
        --os-type linux \
        --os-variant ubuntu${RELEASE_NAME} \
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
}

create_disk
if [ "$NO_PRESEED" != "true" ]; then
    generate_preseed_cfg
    virtinst_with_preseed
    cleanup_preseed_cfg
else
    virtinst_without_preseed
fi
