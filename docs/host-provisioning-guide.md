# Host Provision Utility - User guide and sample invocations

## Why the Host Provision Utility came into being?
Ok, now you got an array of new BMX servers at your hands.
And, you want to get your first Oracle instance up & running asap.

### But, where do you start?
Before you can call the bms-toolkit's install scripts, the BMX host needs to be
configured in such a way that the host can run the install scripts.
Prior to the introduction of the Host Provision utility, you would have to do a
few system configuration tasks, set up connectivity between your control-node/vm
and the BMX hosts, set up user/group for ansible, subscribe to the RHEL
subscription server, etc.
The Host Provision Utility is introduced to automate the configuration steps so
that the subsequent install scripts can be run in quick succession.

## Table of Contents:
<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [Host Provision Utility - User guide and sample invocations](#host-provision-utility-user-guide-and-sample-invocations)
	- [Why the Host Provision Utility came into being?](#why-the-host-provision-utility-came-into-being)
		- [But, where do you start?](#but-where-do-you-start)
	- [Table of Contents:](#table-of-contents)
	- [Schematic](#schematic)
	- [What does it do](#what-does-it-do)
	- [What user inputs are needed](#what-user-inputs-are-needed)
	- [Sample invocations](#sample-invocations)

<!-- /TOC -->

## Schematic
* With the caveat that code structure can quickly go out of date, the following
represents the host-provision utility as it existed as of commit <>.

![Shows codeflow from host-utility.sh command line to the host-provision.yml entry point and on to the leaf scripts.](host-provision-logical-fork-points.png)

The aim of publishing the above code flow is not accuracy or up-to-date codemap,
but rather function as a helpful start so the user can gain the basic understanding of the layout.

## What does it do
* Creates an OS user (ex: `ansible`) in the BMX host that will be performing the ansible tasks
* Creates a SSL public/private key pair using the `id_rsa` algorithm
  * stores the private key locally on the control node
  * transfers the public key to the remote BMX host under the newly created `ansible` user above
  * this enables passwordless connection between control node and BMX host
  * add the `ansible` user to sudoers file
* Optionally, configure the hosts to access internet
* Optionally, for RHEL OS, configure the host to be registered in RHEL's support subscription servers
* Optionally, create a LVM layer on the block device that can be mounted later by `install-oracle.sh`

## What user inputs are needed
* The user needs to be ready to key in the following details when prompted by the utility:
  * `customeradmin` credentials (for first time connection) that come with every newly imaged BMX host
  * RHEL subscription credentials (if the BMX host has a RHEL OS)

## Sample invocations
* To see the options accepted on the command line:
```bash
15:46 $ ./host-provision.sh --help
Command used:
./host-provision.sh --help

	Usage: host-provision.sh
	  --instance-ip-addr <value>
	  [ --instance-ssh-user <value> ]
	  [ --proxy-setup <value> ]
	  [ --u01-lun <value> ]
	  [ --help ]
```

* To create and ansible user named `ansible9` on the BMX host `172.16.30.1` and to setup the proxy settings on the BMX host:
```bash
./host-provision.sh --instance-ip-addr 172.16.30.1  --instance-ssh-user ansible9 --proxy-setup true
```

* To create and ansible user named `ansible9` on the BMX host `172.16.30.1` and setup LVM layer on the block device named: `/dev/mapper/3600a098038314473792b51456555712f`:
```bash
./host-provision.sh --instance-ip-addr 172.16.30.1  --instance-ssh-user ansible9 --proxy-setup false --u01-lun /dev/mapper/3600a098038314344372b4f75392d3850
```
  * The default value for the boolean `proxy-setup` is `false`, hence the above can be simply keyed in as:
```bash
./host-provision.sh --instance-ip-addr 172.16.30.1  --instance-ssh-user ansible9 --proxy-setup false --u01-lun /dev/mapper/3600a098038314344372b4f75392d3850
```
