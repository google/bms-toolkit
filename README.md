# bms-toolkit

Toolkit for installing and creating an initial database on Bare Metal Solution.

## Installing the toolkit ##

Install the toolkit to a Linux machine that will serve as your control node for managing your Oracle installation.

Download the toolkit to your control node by clicking the **Clone or Download** button on the bms-toolkit home page and selecting **Download zip**.

If you are using the Cloud Shell as your control node, download the tool to your $HOME directory.

For more information about installing the toolkit, see [Installing the toolkit](/docs/toolkit-user-guide#installing-the-toolkit).

## Downloading the required Oracle software ##

You need to download the Oracle installation files yourself and then stage them to a repository that is accessible to the toolkit.

For more information about downloading the Oracle installation media for use the the toolkit, see [Downloading and staging the Oracle Software](/docs/toolkit-user-guide#downloading-the-oracle-software).

## Staging the installation media ##

You need to stage the Oracle installation media in a repository that the toolkit can access.

You can use any of the following options as your media repository:

- [Cloud Storage FUSE](https://cloud.google.com/storage/docs/gcs-fuse), an open source [FUSE](http://fuse.sourceforge.net/) adapter that allows you to mount Cloud Storage buckets as file systems on Linux or macOS systems.
- A [Cloud Storage](https://cloud.google.com/storage/docs/introduction) bucket.
- A networked NFS share.

When you run the toolkit, you specify the repository on the `--ora-swlib-type` parameter.

For more information about staging the installation media, see [Downloading and staging the Oracle Software](/docs/toolkit-user-guide#downloading-the-oracle-software).


## Customizing Storage options ##

The ansible variables that define Oracle storage have bogus values set (/dev/sdc_BOGUS); This is so that distracted users don't wipe valuable disks by accident.

You can create a new file in the group_vars folder with a name of your liking (later in the process, the ansible hostgroup name will need to match this filename).


For example:
```
oracle_user_data_mounts:
  - { purpose: software, blk_device: mapper/oracle-u01, fstype: xfs, mount_point: /u01, mount_opts: "defaults" }
  - { purpose: other, blk_device: mapper/oracle-u02, fstype: xfs, mount_point: /u02, mount_opts: "defaults" }
```

This variable defines the location of the u01 and u02 used during the oracle installation process. u01 needs a minimum of xxGb while u02 needs a minimum of xxGb. In this definition, the blk_device variable ommits the `/dev/` portion. This can either be a raw device, such as sdb, sdc etc... or a Logical Volume. If you want to use a logical volume, you will need to use the `/dev/mapper/*` identifier (also ommiting /dev/)

You will also need to define your asm disks.

For example:
```
asm_disks:
- diskgroup: "{{ data_diskgroup }}"
  disks:
  - name: DATA1
    blk_device: /dev/mapper/oracle-data
- diskgroup: "{{ reco_diskgroup }}"
  disks:
  - name: RECO1
    blk_device: /dev/mapper/oracle-reco
- diskgroup: DEMO
  disks:
  - name: DEMO1
    blk_device: /dev/mapper/oracle-demo
```

You can define as many diskgroups as you wish, but you should have at least  `diskgroup: "{{ data_diskgroup }}"` and `diskgroup: "{{ reco_diskgroup }}"`

The "Fast Recovery Area Location" needs a minimum of 12,018MB disk space.

You can also add more disks to a diskgroup:

For example:
```
asm_disks:
- diskgroup: "{{ data_diskgroup }}"
  disks:
  - name: DATA1
    blk_device: /dev/mapper/oracle-data1
  - name: DATA2
    blk_device: /dev/mapper/oracle-data2
  - name: DATA3
    blk_device: /dev/mapper/oracle-data3
- diskgroup: "{{ reco_diskgroup }}"
  disks:
  - name: RECO1
    blk_device: /dev/mapper/oracle-reco

```

In the above example we are using logical volumes. If you want to use logical volumes, then all of your disks in the ASM definition should be logical volumes.

Note that when using Logical Volumes, asmlib will be used, since creating udev rules on LV volumes makes little sense.

You can use exclusively raw devices as well (you can't mix LV and raw devices):
```
asm_disks:
- diskgroup: "{{ data_diskgroup }}"
  disks:
  - name: DATA1
    blk_device: /dev/sdc
  - name: DATA2
    blk_device: /dev/sdd
  - name: DATA3
    blk_device: /dev/sde
- diskgroup: "{{ reco_diskgroup }}"
  disks:
  - name: RECO1
    blk_device: /dev/sdf

```

You can look at the `group_vars/lvm.yml` file for an example.

We provide an `group_vars/db-asm-1.yml` file that works with our default Vagrant disk layout.


#
# compatible.rdbms
#
The --compatible.rdbms option allows to chose the value for this parameter -- if not specified, it takes the value of the Oracle version installed
As documented in https://docs.oracle.com/database/121/OSTMG/GUID-BC6544D7-6D59-42B3-AE1F-4201D3459ADD.htm#GUID-5AC1176D-D331-4C1C-978F-0ECA43E0900F, keep in mind that if compatible.rdbms is set to a value lower than 12.1, each ASM disk has a 2 terabytes (TB) maximum storage limit
#
## Host Setup Steps ##
#
The first set of activities involve setting up the host servers in preparation of installing Oracle software. This can include creating ASM candidate disks (using udev rules, not ASMlib or ASMFD currently).

These activites are mostly root steps and have to be run with superuser privileges.

Run host setup playbook with:

`ansible-playbook prep-host.yml`

#### Summary of Roles ####

| Role | Description |
| --- | --- |
| `base-provision` | DB platform agnostic host pre-requisits (OS alignment) |
| `swlib` | Configures a software library using NFS or GCS |
| `hugepages` | Host configurations for Linux HugePages (and removing RHEL THP) |
| `host-storage` | Add secondary block storage device for ADR and ASM disks as applicable |
| `ora-host` | Other Oracle specific host setup activities |


## Oracle Software Installation Steps ##

Oracle software installations includes options for:
* Grid Infrastructure (for single instance / Oracle Restart)
* Oracle Database

Run Oracle software installation playbook with:

`ansible-playbook install-sw.yml`

#### Summary of Roles ####

| Role | Description |
| --- | --- |
| `gi-setup` |  |
| `gi-install` | Install the Oracle Grid Infrastructure software |
| `asm-create` | Configure ASM instance and create disk groups |
| `rdbms-setup` |  |
| `rdbms-install` | Install the Oracle RDBMS software |


## Database Creation and Configuration Steps ##

Database creation and configuration activities including:
* Listener creation with specified name and listening (TCP) on specified port
* Creating the DB instance
* Basic database adjustments such as enabling of archivelog mode
* Deployment and scheduling of basic RMAN backup scripts

Run the DB creation and configuration playbook with:

`ansible-playbook config-db.yml`

#### Summary of Roles ####

| Role | Description |
| --- | --- |
| `lsnr-create` | Create listener if not already present |
| `db-create` | Create database if not already present |
| `db-adjustements` | Database adjustments such as enabling ARCHIVELOG mode |
| `db-backups` | Deploy and schedule basic RMAN backup scripts |
| `validation-scripts` | Deploy basic environment validation scripts |


## Destructive Clean-up ##

If you need to delete an Oracle installation, the toolkit provides a destructive cleanup option.

For more information, see [Destructive Cleanup](/docs/toolkit-user-guide#destructive-cleanup).


## Execution Instructions ##

An installation shell script is included to provide a simple user experience without the ansible complexity.  The shell script validates related (and specified) environment variables and/or command line arguments.

Example execution:

```bash
./install-oracle.sh --ora-version 19.3.0.0.0 --ora-swlib-bucket gs://foo
```

Alternatively, the Ansible playbooks can be called/run individually.  Sample with custom Vagrant and Ansible paramters:

```bash
vagrant destroy -f ; vagrant up

ansible-playbook prep-host.yml --extra-vars "oracle_ver=19.3.0.0.0"
ansible-playbook install-sw.yml --extra-vars "oracle_ver=19.3.0.0.0"
ansible-playbook config-db.yml --extra-vars "oracle_ver=19.3.0.0.0"
```

---

This is not an officially supported Google product.
