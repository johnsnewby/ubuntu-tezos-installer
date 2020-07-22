# Securing a Tezos baking node

## Overview and scope

This document addresses securing a baking node running on Ubuntu Linux. Instructions have been tested on version 20.04 which is the latest LTE release. They should also work on other versions, but this has not been tested.

The document addresses OS-level security including updates, and firewall rules, and securing the tezos node.

## OS security

### Updates

Unattended upgrades are a thorny question: on the one hand one wants to receive the latest security fixes, on the other hand there are risks involved in installing software unattended. The author's recommendation is to enable automated updates only for non-mission critical services. The [Ubuntu security announce mailing](https://lists.ubuntu.com/mailman/listinfo/ubuntu-security-announce) may be of interest to you in order to be notified of security updates which you can then apply manually.

### ssh

You should be using ssh keys for ssh access, and disable password logins, so that even if your password is compromised your machine will remain inaccessible.

The best practise at the time of writing (July 2020) is to use ed25519 keys, as described in [this article](https://medium.com/risan/upgrade-your-ssh-key-to-ed25519-c6e8d60d3c54).

Generate the key on your local machine with

```bash
ssh-keygen -t ed25519
```
and install it on the server with

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@host
```
where `user` is your username and `host` the hostname of the remote server.

ssh to the remote machine to check that you have passwordless access before attempting the next ststep!

In the file `/etc/ssh/sshd_config` change the line
```bash
#PasswordAuthentication yes
```
to
```
PasswordAuthentication no
```

and restart sshd:

```bash
service sshd restart
```
### Firewall

Even if your machine is behind a firewall, security in depth is a wonderful thing. The Linux operating system comes with the `iptables` firewall built in. Assuming your server is only baking and provides ssh access, the rules would be very simple and only need to be applied to the `INPUT` chain:

```
iptables -F INPUT # flush
iptables -A INPUT -i lo -j ACCEPT # allow connections to loopback device
iptables -I INPUT -p tcp --dport 53 -j ACCEPT # accept DNS
iptables -I INPUT -p tcp --dport 22 -j ACCEPT # allow ssh
iptables -I INPUT -p tcp --dport 8732 -j ACCEPT # accept
iptables -I INPUT -p udp --sport 53 -j ACCEPT
iptables -I INPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -j REJECT
```

If you get the rules wrong you will lose access to the server, assuming it's remote. In order to prevent this it is useful to set a command to run in the future which will remove all rules. If all is well after setting the rules, just delete the command:

```bash
# at now +2 minutes
warning: commands will be executed using /bin/sh
at> /sbin/iptables -F INPUT
at> <EOT>
job 4 at Thu Jul 16 14:05:00 2020
```

you can remove this job with

```
atrm 4 # or whatever the number was
```

To make the rules persistent install the `iptables-persistent` package and save them:

```bash
apt install iptables-persistent
iptables-save > /etc/iptables/rules.v4
```

At this stage I would reboot and check that the firewall rules have been saved, with `iptables -L` -- the output should look like this

```
iptables -F INPUT # flush
iptables -A INPUT -i lo -j ACCEPT # allow connections to loopback device
iptables -I INPUT -p tcp -m tcp --dport 22 -j ACCEPT # accept
iptables -I INPUT -p tcp -m tcp --dport 8732 -j ACCEPT # accept
iptables -I INPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -j REJECT
```

### VPN

To come, nebula is the best for this

## Node configuration

### Sharing ledger using USB over IP

Advantages:
    - works with all software, including Kiln
    - that's it.

Disadvantages
    - fiddly to set up
    - not super reliable

One of the less-known abilities of Linux is to share USB devices over IP. Although it's a little fiddly to set up it turns out to work well. Here are step-by-step instructions. The files [mount-remote-ledger.sh](mount-remote-ledgers.sh) and [share-ledger.sh](share-ledger.sh) in this repository automate much of this.

On both source and destination machines, install the modules and tools to support USB over IP. These are specific to your kernel version; the easiest way to know which packages are required is to attempt to use the `usbip` command and see what the OS tells you to install. My system required `linux-tools-5.4.0-1008-raspi` and `linux-cloud-tools-raspi` but YMMV.

Next, attach the ledger device, enter the PIN and select the Tezos wallet. Check it is visible using lsusb`:

```
Bus 004 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 003 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 001 Device 003: ID 04d9:0141 Holtek Semiconductor, Inc.
Bus 001 Device 009: ID 2c97:0001  USB2.0 Hub
Bus 001 Device 002: ID 2109:3431 VIA Labs, Inc. Hub
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
```
The ledger is the device with ID 2c97:0001. It is unclear why Linux thinks it's a hub. `dmesg` reports is correctly:

```
[10584.376608] usb 1-1.1: new full-speed USB device number 9 using xhci_hcd
[10584.577105] usb 1-1.1: New USB device found, idVendor=2c97, idProduct=0001, bcdDevice= 2.01
[10584.577119] usb 1-1.1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[10584.577130] usb 1-1.1: Product: Nano S
[10584.577140] usb 1-1.1: Manufacturer: Ledger
[10584.577149] usb 1-1.1: SerialNumber: 0001
[10584.649416] hid-generic 0003:2C97:0001.000C: hiddev0,hidraw0: USB HID v1.11 Device [Ledger Nano S] on usb-0000:01:00.0-1.1/input0
[10584.690824] hid-generic 0003:2C97:0001.000D: hiddev1,hidraw1: USB HID v1.11 Device [Ledger Nano S] on usb-0000:01:00.0-1.1/input1
```

In any case we now know what its USB id is (1.1-1) and so we can bind it:

```bash
sudo modprobe usbip-host # needed to serve USB
sudo usbip bind -b 1-1.1
usbip: info: bind device on busid 1-1.1: complete
sudo usbipd -D # run server process
```

Now we can

### Source machine (with ledger attached)

For the purposes of this document I am just using ssh to connect the two machines using a command line like this:

```bash
ssh -R3240:127.0.0.1:3240 user@remote.host
```

Now I can check that everything is working with
```bash
usbip list -r 127.0.0.1
usbip: error: failed to open /usr/share/hwdata//usb.ids
Exportable USB devices
======================
 - 127.0.0.1
      1-1.1: unknown vendor : unknown product (2c97:0001)
           : /sys/devices/platform/scb/fd500000.pcie/pci0000:00/0000:00:00.0/0000:01:00.0/usb1/1-1/1-1.1
           : (Defined at Interface level) (00/00/00)
           :  0 - unknown class / unknown subclass / unknown protocol (03/00/00)
           :  1 - unknown class / unknown subclass / unknown protocol (03/01/01)

```
I do not wish to run anything as root, so I set udev rules [as described by ledger support](https://support.ledger.com/hc/en-us/articles/115005165269-Fix-connection-issues)

```bash
wget -q -O - https://raw.githubusercontent.com/LedgerHQ/udev-rules/master/add_udev_rules.sh | sudo bash
```
I had to reboot after this step in order for it to take effect.

 and now I mount the USB device -- there is [a script for this](mount-remote-ledger.sh):

 ```bash
sudo modprobe vhci-hcd
sudo usbip attach -r 127.0.0.1 -b 1-1.1
```

and I can see the attached device using tezos-client:

```bash
tezos-client list connected ledgers
Warning:

                 This is NOT the Tezos Mainnet.

     The node you are connecting to claims to be running on the
               Tezos Alphanet DEVELOPMENT NETWORK.
          Do NOT use your fundraiser keys on this network.
          Alphanet is a testing network, with free tokens.

## Ledger `drafty-fox-kindly-tiffany`
Found a Tezos Wallet 2.2.5 (git-description: "") application running on
Ledger Nano S at [0006:0008:00].

To use keys at BIP32 path m/44'/1729'/0'/0' (default Tezos key path), use one
of:
  tezos-client import secret key ledger_newby "ledger://drafty-fox-kindly-tiffany/bip25519/0h/0h"
  tezos-client import secret key ledger_newby "ledger://drafty-fox-kindly-tiffany/ed25519/0h/0h"
  tezos-client import secret key ledger_newby "ledger://drafty-fox-kindly-tiffany/secp256k1/0h/0h"
  tezos-client import secret key ledger_newby "ledger://drafty-fox-kindly-tiffany/P-256/0h/0h"

```

## Using the remote signer

Advantages:
    - the right way to do it

Disadvantages
    - Fiddly to set up (but what isn't)

### Set up signer

```bash
./tezos-latest-release/tezos-signer import secret key ledger_newby "ledger://drafty-fox-kindly-tiffany/ed25519/0h/0h"
Please validate (and write down) the public key hash displayed on the Ledger,
it should be equal
to `tz1hf83sreSbzof7WakXiNbjizWVHwDyHFJi`:
Tezos address added: tz1hf83sreSbzof7WakXiNbjizWVHwDyHFJi
ubuntu@ubuntu:~$ ./tezos-latest-release/tezos-signer launch http signer
```

and on the baking machine:

```bash
./tezos-client import secret key ledger_ubuntu http://127.0.0.1:6732/tz1hf83sreSbzof7WakXiNbjizWVHwDyHFJi --force
Warning:

                 This is NOT the Tezos Mainnet.

     The node you are connecting to claims to be running on the
               Tezos Alphanet DEVELOPMENT NETWORK.
          Do NOT use your fundraiser keys on this network.
          Alphanet is a testing network, with free tokens.

Tezos address added: tz1hf83sreSbzof7WakXiNbjizWVHwDyHFJi
```

Output on signing machine:
```bash
Jul 22 06:54:05 - client.signer: Request for public key tz1hf83sreSbzof7WakXiNbjizWVHwDyHFJi
Jul 22 06:54:05 - client.signer: Found public key for hash tz1hf83sreSbzof7WakXiNbjizWVHwDyHFJi (name: ledger_newby)
```

Now we run the endorser:
 ```bash
newby@ubuntu-16gb-nbg1-1:~/tezos-latest-release$ ./tezos-endorser-006-PsCARTHA run ledger_ubuntu                                                Waiting for the node to be synchronized with its peers...
Node synchronized.
Endorser started.
Jul 22 09:06:56 - 006-PsCARTHA.baking.endorsement: Injected endorsement for block 'BLp33yGsCNMM' (level 586146, contract ledger_ubuntu) 'opUUcXzRgKyWb9EQs1GMt9wsx1aaFxhhsMrRPbP8tGnpDThTJ51'
 ```
and we see on the signing machine:
```bash
 Jul 22 07:06:54 - client.signer: Request for signing 42 bytes of data for key tz1hf83sreSbzof7WakXiNbjizWVHwDyHFJi, magic byte = 02
Jul 22 07:06:54 - client.signer: Signing data for key ledger_newby
```
