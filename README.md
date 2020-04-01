# oracle-ansible

Toolkit for installing Oracle and creating an initial database.

## Download the required Software ##

You should download the software yourself from the relevant Oracle download
  websites. You will be accepting Oracle's License agreement by doing this.

If your plan is to run Oracle on GCP, then you should place these archives in
  a GCS bucket with proper ACLs.

If you are just testing out the toolkit with Vagrant, then you could place your
  binaries in a local shared Virtualbox folder in `/u02/swlib`

You also have the option of making these files available through an NFS share.

To work with GCS, you need the gcloud-sdk to be installed and authentication
  configured on your control node.

If you are placing these files in GCS, you can confirm that you have the
  required files to continue by running the following command:

```
./check-swlib.sh --ora-swlib-bucket gs://oracle-swlib --ora-version=18.0.0.0.0
Running with parameters from command line or environment variables:

ORA_SWLIB_BUCKET=gs://oracle-swlib
ORA_VERSION=18.0.0.0.0

Found V978967-01.zip:
  Oracle Database 18.0.0.0.0 for Linux x86-64
  file size matches (4564649047), md5 matches (99a7c4a088a8a502c261e741a8339ae8)

Found V978971-01.zip:
  Oracle Grid Infrastructure 18.0.0.0.0 for Linux x86-64
  file size matches (5382265496), md5 matches (cd42d137fd2a2eeb4e911e8029cc82a9)

Found p29249695_180000_Linux-x86-64.zip:
  Combo of OJVM Update 18.6.0 + DB Update 18.6.0 patch 29249695 for Linux x86-64
  file size matches (816895458), md5 matches (bf2731311ef5f92c38208096f1b8e862)

Found p29301682_180000_Linux-x86-64.zip :
  Grid Infrastructure Release Update 18.6.0 patch 29301682 for Linux x86-64
  file size matches (2231236189), md5 matches (4b30104aea3e9efc5238ebca22999acc)

Found p6880880_180000_Linux-x86-64.zip : OPatch Utility
  file size matches (111682884), md5 matches (ad583938cc58d2e0805f3f9c309e7431).
```

If no file is found, you should re-download the files and place them in
  the GCS bucket and run this script again.

## Point your deployment to the swlib software location ##

`--ora-swlib-type` can have different values:

- empty:   used when we don't want to manage swlib directly, or swlib
           is managed externally (by Vagrant for example)
- gcsfuse: The host will mount the gcs bucket with gcsfuse.
- gcs:     This is a man in the middle copy of a gcs bucket, via your ansible control node, to the host.
- nfs:     Swlib is a network nfs share.

gcfuse:
With the gcsfuse option, you can also pass the location of a gcs service
  account json file. This is useful if your instance doesn't have a
  proper instance service account.
You should also confirm that the instance scopes allow to use gcs storage.
To create a new service account, navigate to your Google Cloud Console,
  select the "IAM & Admin" tab, then "Service accounts".
  Click on "Create Service Account", and chose a relevant name.
  Pick a proper role such as "Storage Admin".
  Click on the "Create Key" button, and download the file in JSON format.
You can then pass the file as a parameter to the deployment:

```
--ora-swlib-type gcsfuse --ora-swlib-bucket oracle-swlib
--ora-swlib-credentials ~/path_to/service_account.json
```
This service account will get uploaded to the server so that gcsfuse can use it.

gcs:
  This relies on gsutil properly configured on the ansible control node.

nfs:
  In this case ora-swlib-bucket is in fact an nfs mount point.
```
--ora-swlib-type nfs --ora-swlib-bucket 192.168.0.250:/my_nfs_export
```


## Customizing Storage options ##

The ansible variables that define Oracle storage have "bogus" values set:
  /dev/BOGUS
  This is so that distracted users don't wipe valuable disks by accident.

You can create a new file in the group_vars folder with a name of your liking
  (later in the process, the ansible hostgroup name will need to match
   this filename).

For example:
```
oracle_user_data_mounts:
  - { purpose: software, blk_device: mapper/oracle-u01, fstype: xfs, mount_point: /u01, mount_opts: "defaults" }
  - { purpose: other, blk_device: mapper/oracle-u02, fstype: xfs, mount_point: /u02, mount_opts: "defaults" }
```

This variable defines the location of the u01 and u02 used during
  the oracle installation process. u01 needs a minimum of xxGb
  while u02 needs a minimum of xxGb. In this definition, the blk_device
  variable omits the `/dev/` portion. This can either be a raw device,
  such as sdb, sdc etc... or a Logical Volume.
  If you want to use a logical volume, you will need to use
  the `/dev/mapper/*` identifier (also ommiting /dev/)

You will also need to define your asm disks. They cal also be defined in 
  the asm_disk_config.json configuration file.

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

You can define as many diskgroups as you wish, but you should have at least
  `diskgroup: "{{ data_diskgroup }}"` and `diskgroup: "{{ reco_diskgroup }}"`

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

In the above example we are using logical volumes. If you want to use logical
  volumes, then all your disks in the ASM definition should be logical volumes.

Note that when using Logical Volumes, asmlib will be used
  since creating udev rules on LV volumes makes little sense.

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

We provide an `group_vars/db-asm-1.yml` file that works with our
  default Vagrant disk layout.


## Testing with Vagrant ##

This toolkit can be tested using the included Vagrant based lab setup.

VM configuration details are specified in the `hosts.yml` file -
  customize as required.

The Vagrant VMs are based on OL7 - the initial source box will be downloaded
  on first run. Create VMs using simple commands such as:

```bash
vagrant destroy -f ; vagrant up
```

If the /u02/swlib/ folder exists on your control node, it will be mounted
  by Vagrant to /swlib/. You need to have the Oracle archives in this folder.
If you have files in a gcs bucket instead, just add `--ora-swlib-type gcs`
  or `--ora-swlib-type gcsfuse` along with `--ora-swlib-bucket your_bucket_name`
  to the following command line.

```
./install-oracle.sh --ora-swlib-bucket oracle-swlib --backup-dest /backups --ora-swlib-path /swlib/ --ora-version 18.0.0.0.0
```

The following default values are used (no need to add these to the command line)

```
--instance-ip-addr 192.168.56.201 --instance-ssh-user vagrant --instance-ssh-key .vagrant/machines/oracledb1/virtualbox/private_key --instance-ansible-hostname oracledb1 --instance-ansible-hostgroup-name dbasm
```


This will launch the installation process which takes approximately 20 minutes.

This wrapper script create an inventory file for ansible,
  using `--instance-ansible-hostgroup-name db-asm-1` as a hostgroup name.
This is where the hostgroup name needs to match the customized group_vars
  file we have created previously.

#
# compatible.rdbms
#
The --compatible.rdbms option allows to chose the value for this parameter
  if not specified, it takes the value of the Oracle version installed
As documented in https://docs.oracle.com/database/121/OSTMG/GUID-BC6544D7-6D59-42B3-AE1F-4201D3459ADD.htm#GUID-5AC1176D-D331-4C1C-978F-0ECA43E0900F,
  keep in mind that if compatible.rdbms is set to a value lower than 12.1,
  each ASM disk has a 2 terabytes (TB) maximum storage limit

## Host Setup Steps ##

The first set of activities involve setting up the host servers in preparation
  of installing Oracle software. This can include creating ASM candidate disks
   (using udev rules, not ASMlib or ASMFD currently).

These activites are mostly root steps and have to be run with root privileges.

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

An additional role & playbook performs a desructive brute-force removal of
  Oracle software and configuration. It does not remove other host prerequisites

Run the desructive brute-force Oracle software removal with:

`cleanup-oracle.sh` or `ansible-playbook brute-cleanup.yml`


## Execution Instructions ##

An installation shell script is included to provide a simple user experience
  without the ansible complexity. The shell script validates related
  (and specified) environment variables and/or command line arguments.

Example execution:

```bash
./install-oracle.sh --ora-version 19.3.0.0.0 --ora-swlib-bucket gs://foo
```

Alternatively, the Ansible playbooks can be called/run individually.
Sample with custom Vagrant and Ansible paramters:

```bash
vagrant destroy -f ; vagrant up

ansible-playbook prep-host.yml --extra-vars "oracle_ver=19.3.0.0.0"
ansible-playbook install-sw.yml --extra-vars "oracle_ver=19.3.0.0.0"
ansible-playbook config-db.yml --extra-vars "oracle_ver=19.3.0.0.0"
```
