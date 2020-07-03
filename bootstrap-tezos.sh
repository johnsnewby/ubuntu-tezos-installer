#!/bin/bash
#
# Script to install Tezos, part 1. This script install dependencies and sets up a Tezos node for you.
#
#set -e # halt on error
#
# Minimum version of opam we should use. The script will check for this in /usr/local/bin and upgrade if necessary
export MINIMUM_OPAM_VERSION=2.0.7

# Set the TEZOS_USER variable to have this script create the user if it does not exist, and
# compile the node in that user's home directory
#TEZOS_USER=tezos

# Set the TEZOS_BRANCH variable to build anything other than latest-release.
if [ -z $TEZOS_BRANCH ]; then
    export TEZOS_BRANCH=latest-release
fi

echo "installing prerequisites"
sudo apt-get install build-essential git m4 unzip rsync curl libev-dev libgmp-dev pkg-config libhidapi-dev bubblewrap jq

NEED_OPAM=1
if [ -x /usr/local/bin/opam ]; then
    export OPAM_VERSION=`/usr/local/bin/opam --version`
    if [ ! -z $OPAM_VERSION ]; then
        if (( $(echo "$OPAM_VERSION $MINIMUM_OPAM_VERSION" | awk '{print ($1 >= $2)}') )); then
            echo "Opam installed version is $OPAM_VERSION"
            unset NEED_OPAM
        fi
    else
        echo "Need to upgrade Opam"
    fi
fi

if [ ! -z $NEED_OPAM ]; then
    echo "Installing new opam under /usr/local/bin"
    sudo wget -O /usr/local/bin/opam https://github.com/ocaml/opam/releases/download/2.0.7/opam-$MINIMUM_OPAM_VERSION-x86_64-linux
    sudo chmod 755 /usr/local/bin/opam
fi

script_path=`dirname $0`

if [ ! -z $TEZOS_USER ]; then
    exists=$(grep -c '^$TEZOS_USER:' /etc/passwd)
    echo "exists=$exists"
    if [ $exists -eq 0 ]; then
        echo "Creating user $TEZOS_USER"
        sudo adduser $TEZOS_USER
        sudo adduser $TEZOS_USER sudo
        cp $script_path/bootstrap-tezos2.sh /tmp
        sudo su - $TEZOS_USER -c /tmp/bootstrap-tezos2.sh
        rm /tmp/bootstrap2.sh
    fi
else
    $script_path/bootstrap-tezos2.sh
fi
