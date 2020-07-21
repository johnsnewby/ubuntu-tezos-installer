#!/bin/sh

set -e # exit on error

USB_ID=`usbip list -l|grep 2c97:0001|head -n1|awk '{print $3}'`

if [ -z $USB_ID ]; then
    echo "Device not found"
    exit
fi

sudo modprobe usbip-host
sudo usbip unbind -b $USB_ID || true
sudo usbip bind -b $USB_ID
sudo usbipd -D
echo "Success"



