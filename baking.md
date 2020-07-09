# Tezos baking howto

## Overview

This howto goes through the process of setting up baking on an Ubuntu Linux machine. The steps described are:
- (optionally) creating a user, and switching to it
- cloning the repository containing the node
- installing prerequisites
- installing opam, the Ocaml package manager
- building the node
- creating an identity
- for the testnet, getting and installing tokens from the faucet, and setting yourself up for baking
- for the mainnet, TO COME
- starting the baking pricess and connecting it to your local node.

## Setup

### Prerequisites

You have to install some dependencies. In debian / ubuntu run:

```bash
sudo apt-get install build-essential git m4 unzip rsync curl libev-dev libgmp-dev pkg-config libhidapi-dev bubblewrap jq
```

#### (Optional) create an user and switch to it:

```bash
adduser tezos
adduser tezos sudo
su - tezos
```

### Install the node from sources

Checkout the code:

```bash
git clone https://gitlab.com/tezos/tezos.git
cd tezos
git checkout latest-release
```

Install Opam if you don't already have it

```bash
wget https://github.com/ocaml/opam/releases/download/2.0.7/opam-2.0.7-x86_64-linux
sudo mv opam-2.0.7-x86_64-linux /usr/local/bin/opam
sudo chmod a+x /usr/local/bin/opam
opam init --comp=4.09.1 --disable-sandboxing
opam switch create tezos ocaml-base-compiler.4.09.1
opam switch tezos
opam update
eval $(opam env)
```

Update Opam (if you have already installed it):

```bash
opam update
opam switch create tezos ocaml-base-compiler.4.09.1
opam switch tezos ocaml-base-compiler.4.09.1
eval $(opam env)
```

Then compile the tezos node:

```bash
make build-deps
eval $(opam env)
make
```


### Update the node

```bash
git pull
make build-deps
eval $(opam env)
make
```

### Node configuration

If this is just an update, you should skip this step.

Generate a new identity and setup config:

```bash
./tezos-node identity generate
```

### Get rid of old artefacts

If you're switching networks, or if you want to, you should remove the old node data:

```bash
rm -rf ~/.tezos-node/context ~/.tezos-node/store ~/.tezos-node/lock
```

## Fast sync from a mainnet snapshot

First download the latest snapshot for tezos mainnet from here, like this:

```bash
curl -s https://api.github.com/repos/Phlogi/tezos-snapshots/releases/latest | jq -r ".assets[] | select(.name) | .browser_download_url" | grep full | xargs wget -q --show-progress
cat mainnet.full.* | xz -d -v -T0 > mainnet.importme
```

Then run the following command:

```bash
./tezos-node snapshot import ../mainnet.importme
```

And run the node normally.


### Start the node

If you did not do a fast sync, above, this will take a long time.

```bash
cd tezos
nohup ./tezos-node run --rpc-addr 127.0.0.1:8732
```



## Funding

### Redeem a faucet (only for carthagenet)

Get a faucet from https://faucet.tzalpha.net/

Then reedem the faucet:

```bash
./tezos-client activate account "my_account" with "./faucet.json"
./tezos-client get balance for "my_account"
```

You need to have enough tez in the delegate in order to bake. So if the balance is less than 10k, redeem another faucet.


### Redeem your contribution (only for mainnet)

First, activate your account using the kyc code:

```bash
./tezos-client add address fundraiser <tz1...>
./tezos-client activate fundraiser account fundraiser with <activation_key>
```

You can check if the account has been activated by getting its balance:

```bash
./tezos-client get balance for fundraiser
```

Then in order to access your funds importing your private key type the following command and write your private data when asked:

```bash
./tezos-client import fundraiser secret key "my_account"
```

Please be careful, you are importing your tezos private keys!



## Baking

### Register a delegate

Register a new delegate:

```bash
./tezos-client register key "my_account" as delegate
```

### Start the baker

Use screen to start the baker and run it in background; it will ask you for the encryption key.
```bash
cd tezos
./tezos-baker-003-PsddFKi3 run with local node "/home/tezos/.tezos-node" "my_account"
```

```bash
cd tezos
./tezos-endorser-003-PsddFKi3 run "my_account"
```

```bash
cd tezos
./tezos-accuser-003-PsddFKi3 run
```

## Voting
If you don't want to bake, you can vote another delegate. To vote a delegate, you should first "originate an account"; consider the implicit account called my_account2 with 6900XTZ, delegating to my_account:

```bash
./tezos-client originate account "my_originated" for "my_account2" transferring 6900 from "my_account2" --delegate "my_account" --delegatable
```

If you already have an originated account, you can delegate running:

```bash
./tezos-client set delegate for "my_originated" to "my_account"
```

## Backup your keys

You private keys are located in:

- /home/tezos/.tezos-node/identity.json
- /home/tezos/.tezos-client/secret_keys.json
