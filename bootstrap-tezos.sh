#!/bin/bash
#
# Script to install Tezos, part 1. This script install dependencies and sets up a Tezos node for you.
#
#set -e # halt on error
#
# Minimum version of opam we should use. The script will check for this in /usr/local/bin and upgrade if necessary
export MINIMUM_OPAM_VERSION=2.0.7

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

opam switch create tezos ocaml-base-compiler.4.09.1 || true # OK if this fails
opam switch tezos
opam update
eval $(opam env)

echo "Compiling dependencies"
make build-deps

echo "Building"
eval $(opam env)
make
