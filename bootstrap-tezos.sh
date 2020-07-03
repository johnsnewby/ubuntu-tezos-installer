#!/bin/bash
#
# Script to install Tezos. This script install dependencies and sets up a Tezos node for you.
# (c) 2020 Tz Connect GmbH.
# This code is licensed under the MIT License, https://opensource.org/licenses/MIT
#
# You may set some environment variables to change the behavior of the script. Options are
# - TEZOS_BRANCH - defaults to latest-release, which will build the latest mainnet.
# - SNAPSHOT     - will populate the new node from a snapshot file. The special value 'mainnet' causes
#                  the script to download the latest mainnet snapshot from https://github.com/Phlogi/tezos-snapshots
#                  and install that. The special value 'carthagenet' download a recent-ish snapshot from
#                  https://snapshots.tulip.tools
#
set -e # halt on error
#
# Minimum version of opam we should use. The script will check for this in /usr/local/bin and upgrade if necessary
export MINIMUM_OPAM_VERSION=2.0.7
ORIG_PWD=`pwd`

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

ARCH=`uname -m`

if [ ! -z $NEED_OPAM ]; then
    echo "Installing new opam under /usr/local/bin"
git     sudo wget -O /usr/local/bin/opam https://github.com/ocaml/opam/releases/download/2.0.7/opam-$MINIMUM_OPAM_VERSION-$ARCH-linux
    sudo chmod 755 /usr/local/bin/opam
fi

TEZOS_DIR="tezos-$TEZOS_BRANCH"

if [ -d $TEZOS_DIR ]; then
    if grep 'url = https://gitlab.com/tezos/tezos.git' $TEZOS_DIR/.git/config; then
        echo "Using existing repo"
        cd $TEZOS_DIR
        git checkout master
    else
        echo "directory $TEZOS_DIR found which is not a tezos repo. Bailing."
        exit 0
    fi
else
    git clone https://gitlab.com/tezos/tezos.git $TEZOS_DIR
    cd $TEZOS_DIR
fi

git checkout $TEZOS_BRANCH

if [ -d ~/.opam ]; then
    opam update
else
    opam init --comp=4.09.1 --disable-sandboxing
fi

echo "Setting up opam environment"

SWITCH=tezos-$TEZOS_BRANCH

opam switch create $SWITCH ocaml-base-compiler.4.09.1 || true # OK if this fails
opam switch $SWITCH
opam update
eval $(opam env)

echo "Compiling dependencies"
make build-deps

echo "Building"
eval $(opam env)
make

# if there is no identity, make one.
if [ ! -f ~/.tezos-node/identity.json ]; then
    ./tezos-node identity generate
fi

# If var SNAPSHOT is set, then:
# - if set to mainnet, download the most recent mainnet snapshot from https://github.com/Phlogi/tezos-snapshots
# - otherwise, try to restore from the file in the variable.
if [ ! -z $SNAPSHOT ]; then
    if [ -f ~/.tezos-node/lock ] || [ -d ~/.tezos-node/store ] || [ -d ~/.tezos-node/context ]; then
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "!!!! Existing chain data will be overridden. Interrupt within 5 seconds to abort !!!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        sleep 5
        rm -rf ~/.tezos-node/context ~/.tezos-node/store ~/.tezos-node/lock
    fi
    if [ $SNAPSHOT == 'mainnet' ]; then
        echo "Downloading mainnet snapshot"
        curl -s https://api.github.com/repos/Phlogi/tezos-snapshots/releases/latest | jq -r ".assets[] | select(.name) | .browser_download_url" | grep full | xargs wget -q --show-progress
        cat mainnet.full.* | xz -d -v -T0 > mainnet.importme
        rm -f mainnet.full.*
        SNAPSHOT=mainnet.importme
	./tezos-node config init --network=mainnet
    elif [ $SNAPSHOT == 'carthagenet' ]; then
	wget https://snaps.tulip.tools/carthagenet_2020-07-03_04:00.full -O carthagenet.importme
	SNAPSHOT=carthagenet.importme
	./tezos-node config init --network=carthagenet
    else
        SNAPSHOT=$ORIG_PWD/$SNAPSHOT
	echo "Please enter the name of network which should be initialized:"
	read network
	./tezos-node config init --network=$network
    fi

    ./tezos-node snapshot import $SNAPSHOT
fi
