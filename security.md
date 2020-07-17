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

ssh to the remote machine to check that you have passwordless access before attempting the next step!

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
