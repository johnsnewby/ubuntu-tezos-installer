#!/bin/bash

set -e # halt on error

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
