#!/bin/bash

WORKDIR=`dirname $0`
source $WORKDIR/config-common.sh

export LANG=C

if [ -z "$1" ]; then
    echo "Usage: $0 NAME"
    exit 1
fi
NAME=$1

STATE=`virsh domstate $NAME 2>/dev/null`
if [ $? -eq 0 ]; then
    if [ "$STATE" != "shut off" ]; then
        echo -n "$NAME is not shut off ($STATE). Force shut off it? [y/n] "
        read answer
        if [[ "$answer" =~ ^[yY] ]]; then
            virsh destroy $NAME
            sleep 1
        else
            echo "Abort because $NAME is not shut off."
            exit 3
        fi
    fi
    virsh undefine $NAME
else
    echo "[Skipped] $NAME is not defined."
fi

IMAGE_NAME=$DISKIMG_DIR/$NAME.img
if [ -f $IMAGE_NAME ]; then
    rm -f -v $IMAGE_NAME
else
    echo "[Skipped] $IMAGE_NAME does not exist."
fi
