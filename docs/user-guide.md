---
published: True
---

# Toolkit for Bare Metal Solution: User Guide

## Table of Contents

- [Command quick reference for single instance deployments](#command-quick-reference-for-single-instance-deployments)
- [Command quick reference for RAC deployments](#command-quick-reference-for-rac-deployments)
- [Command quick reference for DR deployments](#command-quick-reference-for-dr-deployments)
- [Overview](#overview)
  - [Software Stack](#software-stack)
  - [Requirements and Prerequisites](#requirements-and-prerequisites)
    - [Control node requirements](#control-node-requirements)
    - [Target server requirements](#target-server-requirements)
- [Installing the toolkit](#installing-the-toolkit)
- [Downloading and staging the Oracle Software](#downloading-and-staging-the-oracle-software)
  - [Downloading the Oracle installation software](#downloading-the-oracle-installation-software)
    - [Downloading Patches from My Oracle Support](#downloading-patches-from-my-oracle-support)
    - [Required Oracle Software - Download Summary](#required-oracle-software---download-summary)
  - [Staging the Oracle installation media](#staging-the-oracle-installation-media)
    - [Cloud Storage bucket](#cloud-storage-bucket)
    - [Cloud Storage FUSE](#cloud-storage-fuse)
    - [NFS share](#nfs-share)
  - [Validating Media](#validating-media)
- [Prerequisite configuration](#prerequisite-configuration)
  - [Data mount configuration file](#data-mount-configuration-file)
  - [ASM disk group configuration file](#asm-disk-group-configuration-file)
  - [Specifying LVM logical volumes](#specifying-lvm-logical-volumes)
- [Configuring Installations](#configuring-installations)
  - [Configuration defaults](#configuration-defaults)
  - [Oracle User Directories](#oracle-user-directories)
  - [Database backup configuration](#database-backup-configuration)
  - [Parameters](#parameters)
    - [Target environment parameters](#target-environment-parameters)
    - [Software installation parameters](#software-installation-parameters)
    - [Storage configuration parameters](#storage-configuration-parameters)
    - [Database configuration parameters](#database-configuration-parameters)
    - [RAC configuration parameters](#rac-configuration-parameters)
    - [Backup configuration parameters](#backup-configuration-parameters)
    - [Additional operational parameters](#additional-operational-parameters)
  - [Example Toolkit Execution](#example-toolkit-execution)
- [Post installation tasks](#post-installation-tasks)
  - [Reset passwords](#reset-passwords)
  - [Validate the environment](#validate-the-environment)
    - [Listing Oracle ASM devices](#listing-oracle-asm-devices)
    - [Displaying cluster resource status](#displaying-cluster-resource-status)
    - [Verify an Oracle cluster](#verify-an-oracle-cluster)
    - [Oracle validation utilities](#oracle-validation-utilities)
  - [Patching](#patching)
  - [Patching RAC databases](#patching-rac-databases)
  - [Destructive Cleanup](#destructive-cleanup)

## Command quick reference for single instance deployments

Sample commands for a simple quick-start and basic toolkit usage for an Oracle
"single instance" database. Refer to the remainder of this document for
additional details and comprehensive explanations of the toolkit, scripting,
options, and usage scenarios. All commands run from the "control node".

1. Validate media specifying GCS storage bucket and optionally database:

    ```bash
    ./check-swlib.sh --ora-swlib-bucket gs://[cloud-storage-bucket-name] \
     --ora-version 19.3.0.0.0
    ```

1. Validate access to target server (optionally include -i and location of
   private key file):

   ```bash
   ssh ${INSTANCE_SSH_USER:-`whoami`}@${INSTANCE_IP_ADDR} sudo -u root hostname
   ```

1. Review toolkit parameters:

   ```bash
   ./install-oracle.sh --help
   ```

1. Run an installation:

   ```bash
   ./install-oracle.sh \
   --ora-swlib-bucket gs://[cloud-storage-bucket-name] \
   --backup-dest "+RECO" \
   --ora-swlib-path /u02/swlib/ \
   --ora-swlib-type gcs \
   --instance-ip-addr ${INSTANCE_IP_ADDR}
   ```

## Command quick reference for RAC deployments

Sample installation for an Oracle Real Application Clusters (RAC) installation.
Initial steps similar to those of the Single Instance installation.

1. Validate media specifying Cloud Storage bucket and optionally database
   version:

   ```bash
   ./check-swlib.sh --ora-swlib-bucket gs://[cloud-storage-bucket-name]
   --ora-version 19.3.0.0.0
   ```

1. Validate access to target RAC nodes:

    ```bash
    ssh ${INSTANCE_SSH_USER:-`whoami`}@${INSTANCE_IP_ADDR_NODE_1} sudo -u root hostname
    ssh ${INSTANCE_SSH_USER:-`whoami`}@${INSTANCE_IP_ADDR_NODE_2} sudo -u root hostname
    ```

1. Review optional toolkit parameters:

   `./install-oracle.sh --help`

1. Create the cluster configuration file by editing the `cluster_config.json` file template that is provided with the toolkit.

1. Install the database with the path to the cluster configuration file specified on the `--cluster-config` property:

   ```bash
   ./install-oracle.sh \
   --ora-swlib-bucket gs://[cloud-storage-bucket-name] \
   --backup-dest "+RECO" \
   --ora-swlib-path /u02/swlib/ \
   --ora-swlib-type gcs \
   --cluster-type RAC \
   --cluster-config cluster_config.json
   ```

## Command quick reference for DR deployments

The primary database must exist before you can create a standby database.

When you create the primary database, omit the `--cluster-type` option or set it to `NONE`. To create the primary database, see [Single Instance Deployments section](#command-quick-reference-for-single-instance-deployments).

To create a standby database, add the following options to the command options that you used to create the primary database:
- `--primary-ip-addr ${PRIMARY_IP_ADDR}`
- `--cluster-type DG`

1. Install a standby database:

   ```bash
   ./install-oracle.sh \
   --ora-swlib-bucket gs://[cloud-storage-bucket-name] \
   --instance-ip-addr ${INSTANCE_IP_ADDR} \
   --ora-swlib-path /u02/swlib/ \
   --backup-dest "+RECO" \
   --ora-swlib-type gcs \
   --primary-ip-addr ${PRIMARY_IP_ADDR} \
   --cluster-type DG
   ```


## Overview

The Implementation Toolkit for Oracle provides an automated (scripted) mechanism
to help you install Oracle software and configure an initial Oracle database on
the Google Cloud Bare Metal Solution. You can also use the toolkit to provision
initial Oracle Database Recovery Manager (RMAN) backups to Google Cloud Storage
or another storage system.

This guide is for experienced professional users of Oracle software who are
deploying Oracle Database software and preparing initial Oracle databases on
Google Cloud [Bare Metal Solution](https://cloud.google.com/bare-metal).
The toolkit defines default values for most options, so you can run the toolkit
with only a few specifications. Your configuration options are listed later in
this guide.

The toolkit supports the following major releases of Oracle Database and applies
the most recent quarterly patches, also known as Oracle Release Updates or
RUs:

- Oracle 11.2.0.4.0
- Oracle 12.1.0.2.0
- Oracle 12.2.0.1.0
- Oracle 18c
- Oracle 19c

The toolkit does not include any Oracle software. You must obtain the
appropriate licenses and download the Oracle software on your own. This guide
provides information about where to obtain Oracle software solely for your
convenience.

After downloading the Oracle software, you stage the software in a Cloud Storage
bucket where the toolkit can access it.

### Software Stack

The toolkit customizes the software stack for Oracle Database workloads. Any out
of a number of Oracle Database software releases can be installed. In addition,
the configuration of the software stack includes:

- The Oracle Grid Infrastructure (GI) and Automatic Storage Manager (ASM),
  at the same major release as the database software.
- The configuration of Oracle resources, like the database, listener, and
  ASM resources, via
  "[Oracle Restart](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/configuring-automatic-restart-of-an-oracle-database.html)"
  for single-instance deployments and Oracle Clusterware for RAC deployments.
- The optional separation of OS roles,"role separation," so you can have
  different OS users for the GI and database software.
- The installation of all of the required OS packages that are necessary for
  the Oracle software installation, including common packages, such as ntp,
  bind-utils, unzip, expect, wget, and net-tools.
- The configuration of Linux Huge Pages, usually as a percentage of the
  available memory, and the disabling of Red Hat Transparent Huge Pages (THP),
  as per the recommended Oracle practices.
- The adjustment of Linux kernel settings, as necessary. For more
  information, see the
  [Oracle documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/minimum-parameter-settings-for-installation.html).
- The disabling of the Linux firewall and SELinux, as recommended for Oracle
  database servers.
- The creation of a swap device, as necessary.

You can further customize the environment and host server(s), as needed.

### Requirements and Prerequisites

You need at least two servers to install Oracle software by using the toolkit:

- **Control node**: a virtual or physical machine from which the toolkit is
  executed.
- **Database server(s)**: target where the Oracle software will be installed
  and configured.

A second database server (or node) is required for RAC deployments.

![Shows workflow from user through control node to staging repository and then
to servers in the Bare Metal Solution environment. A dotted line goes to Cloud
Storage for backups.](bms-toolkit-architecture.png)

#### Control node requirements

The control node can be any server capable of ssh.

The control node must have the following software installed:

- [Ansible]([https://en.wikipedia.org/wiki/Ansible_(software)](https://en.wikipedia.org/wiki/Ansible_(software)))
  version 2.9 or higher.
- If you are using a Cloud Storage bucket to stage your Oracle installation
  media, the [Google Cloud SDK](https://cloud.google.com/sdk/docs).
- Ideally, a mainstream Linux OS.

Depending on the Linux distribution you are using on your control node, you can
install Ansible with `sudo apt-get install ansible`. Your installation command
might be different. You can verify your version of Ansible with ansible
`--version`.

You can use the [Google Cloud
Shell]([https://cloud.google.com/shell](https://cloud.google.com/shell)) as your
control node. Cloud Shell provides command-line access to a virtual machine
instance in a terminal window that opens in the web console. The latest version
of Cloud SDK is installed for you.

#### Target server requirements

Prior to running the toolkit, ensure that the control node has SSH access to a
Linux user account on the target server. The user account must have elevated
security privileges, such as granted by "sudo su -", to install and configure
Oracle software. The toolkit creates _Oracle software owners_, such as `oracle`
and `grid`.

The target database server(s) must be running a version of Linux that is
certified for Oracle Database. The toolkit currently supports the following
certified OS versions:

- Red Hat Enterprise Linux (RHEL) 7 (versions 7.3 and up).
- Oracle Linux (OL) 7 (versions 7.3 and up).

For more information about Oracle-supported platforms see the Oracle
certification matrix in the "My Oracle Support" (MOS) site (sign in required):
[https://support.oracle.com](https://support.oracle.com).

## Installing the toolkit

The latest version of the toolkit can be downloaded from Google Git
Repositories:
[https://github.com/google/bms-toolkit](https://github.com/google/bms-toolkit)

On the `google/bms-toolkit` home page in GitHub, download the toolkit to your
control node by clicking the **Clone or Download** button and selecting
**Download zip**.

If you are using the Cloud Shell as your control node, download the tool to your
$HOME directory.

## Downloading and staging the Oracle Software

You must download and stage the Oracle software yourself, in accordance with the
applicable licenses governing such software. The toolkit doesn't contain any
Oracle software. You are responsible for procuring the Oracle software that you
need and for complying with the applicable licenses.

### Downloading the Oracle installation software

Oracle software is divided into two general categories: **base software** that
you download from the [Oracle Software Delivery
Cloud](https://edelivery.oracle.com/) site (also known as Oracle "eDelivery"),
and **patches** that you download from Oracle's [My Oracle
Support](https://support.oracle.com/) (MOS) site.

One key exception: Oracle 11g base software can be downloaded directly from My
Oracle Support. Only Oracle 12c or later base software needs to be downloaded
from Oracle Software Delivery Cloud. Direct links to MOS downloads are provided
below.

Before you download Oracle software and patches, review and acknowledge Oracle's
license terms.

Before using the toolkit, download all of the software pieces for your Oracle
release, including the base release, patchsets, the OPatch utility, and any
additional patches listed by Oracle.

Do not unzip the downloaded installation files. The toolkit requires the
downloads in their original, compressed-file format.

#### Downloading Patches from My Oracle Support

For convenience, direct links to My Oracle Support (MOS) for applicable patches
are listed in the following section. You need an Oracle Single Sign-on account
that is linked to a valid Oracle Customer Support Identifier (CSI) to download
patches through My Oracle Support.

#### Required Oracle Software - Download Summary

<table>
<thead>
<tr>
<th>Oracle Release</th>
<th>Category - Site</th>
<th>Software Piece</th>
<th>File Name<br>
(From "Oracle eDelivery" or "My Oracle
Support")</th>
</tr>
</thead>
<tbody>
<tr>
<td>19.3.0.0.0</td>
<td>Base - eDelivery</td>
<td>Oracle Database 19.3.0.0.0 for Linux x86-64</td>
<td>V982063-01.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Oracle Grid Infrastructure 19.3.0.0.0 for Linux x86-64</td>
<td>V982068-01.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>COMBO OF OJVM RU COMPONENT 19.9.0.0.201020 + GI RU 19.9.0.0.201020</td>
<td>p31720429_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 19.8.0.0.200714 + GI RU 19.8.0.0.200714</td>
<td>p31326369_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 19.7.0.0.200414 + GI RU 19.7.0.0.200414</td>
<td>p30783556_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 19.6.0.0.200114 GI RU 19.6.0.0.200114</td>
<td>p30463609_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 19.5.0.0.191015 GI RU 19.5.0.0.191015</td>
<td>p30133178_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 19.4.0.0.190716 + GI RU 19.4.0.0.190716</td>
<td>p29699097_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>OPatch Utility </td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000122912&patchId=6880880&languageId=0&platformId=226">p6880880_190000_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td>18.0.0.0.0</td>
<td>Base - eDelivery</td>
<td>Oracle Database 18.0.0.0.0 for Linux x86-64</td>
<td>V978967-01.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Oracle Grid Infrastructure 18.0.0.0.0 for Linux x86-64</td>
<td>V978971-01.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>COMBO OF OJVM RU COMPONENT 18.12.0.0.201020 + GI RU 18.12.0.0.201020</td>
<td>p31720457_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.11.0.0.200714 + GI RU 18.11.0.0.200714</td>
<td>p31326376_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.10.0.0.200414 GI RU 18.10.0.0.200414</td>
<td>p30783607_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.9.0.0.200114 GI RU 18.9.0.0.200114</td>
<td>p30463635_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.8.0.0.191015 GI RU 18.8.0.0.191015</td>
<td>p30133246_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.7.0.0.190716 + GI RU 18.7.0.0.190716</td>
<td>p29699160_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.6.0.0.190416 + GI RU 18.6.0.0.190416</td>
<td>p29251992_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>OPatch Utility</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000107457&patchId=6880880&languageId=0&platformId=226">p6880880_180000_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td>12.2.0.1.0</td>
<td>Base - eDelivery</td>
<td>Oracle Database 12.2.0.1.0 for Linux x86-64</td>
<td>V839960-01.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Oracle Grid Infrastructure 12.2.0.1.0 for Linux x86-64 for Linux
x86-64</td>
<td>V840012-01.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.201020 + 12.2.0.1.201020 GIOCT2020RU</td>
<td>p31720486_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.200714 + 12.2.0.1.200714 GIJUL2020RU</td>
<td>p31326390_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.200414 12.2.0.1.200414 GIAPR2020RU</td>
<td>p30783652_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.200114 12.2.0.1.200114 GIJAN2020RU</td>
<td>p30463673_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.191015 12.2.0.1.191015 GIOCT2019RU</td>
<td>p30133386_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.190716 + 12.2.0.1.190716
GIJUL2019RU</td>
<td>p29699173_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.190416 + 12.2.0.1.190416
GIAPR2019RU</td>
<td>p29252072_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>ACFS MODULE ORACLEACFS.KO FAILS TO LOAD ON OL7U3 SERVER WITH RHCK (Patch)
patch 25078431 for Linux x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000018520&patchId=25078431&languageId=0&platformId=226">p25078431_122010_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td></td>
<td></td>
<td>OPatch Utility</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000063735&patchId=6880880&languageId=0&platformId=226">p6880880_122010_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td>12.1.0.2.0</td>
<td>Base - eDelivery</td>
<td>Oracle Database 12.1.0.2.0 for Linux x86-64</td>
<td>V46095-01_1of2.zip<br>
V46095-01_2of2.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Oracle Database 12c Standard Edition 2 12.1.0.2.0 for Linux x86-64</td>
<td>V77388-01_1of2.zip<br>
V77388-01_2of2.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Oracle Grid Infrastructure 12.1.0.2.0 for Linux x86-64</td>
<td>V46096-01_1of2.zip<br>
V46096-01_2of2.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.201020 DB PSU + GIPSU 12.1.0.2.201020</td>
<td>p31720761_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.200714 DB PSU + GIPSU 12.1.0.2.200714</td>
<td>p31326400_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.200414 DB PSU GIPSU 12.1.0.2.200414</td>
<td>p30783882_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.200114 DB PSU GIPSU 12.1.0.2.200114</td>
<td>p30463691_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.191015 DB PSU GIPSU 12.1.0.2.191015</td>
<td>p30133443_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.190716 DB PSU + GIPSU 12.1.0.2.190716</td>
<td>p29699244_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.190416 DB PSU + GIPSU 12.1.0.2.190416</td>
<td>p29252164_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Combo OJVM PSU 12.1.0.2.190416 and Database Proactive BP 12.1.0.2.190416
patch 29252171 for Linux x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000009300&patchId=29252171&languageId=0&platformId=226">p29252171_121020_Linux-x86-64.zip</a></td>
</tr><tr>
<td></td>
<td></td>
<td>GI PSU 12.1.0.2.190416 patch 29176115 for Linux x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000009300&patchId=29176115&languageId=0&platformId=226">p29176115_121020_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td></td>
<td></td>
<td>OPatch Utility</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80121010&patchId=6880880&languageId=0&platformId=226">p6880880_121010_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td>11.2.0.4</td>
<td>Patch - MOS</td>
<td>11.2.0.4.0 PATCH SET FOR ORACLE DATABASE SERVER - Patch 13390677 for Linux
x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80112040&patchId=13390677&languageId=0&platformId=226">p13390677_112040_Linux-x86-64_1of7.zip</a><br>
<a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80112040&patchId=13390677&languageId=0&platformId=226">p13390677_112040_Linux-x86-64_2of7.zip</a></td>
</tr>
<tr>
<td></td>
<td></td>
<td>11.2.0.4.0 PATCH SET FOR ORACLE DATABASE SERVER - Patch 13390677 for Linux
x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80112040&patchId=13390677&languageId=0&platformId=226">p13390677_112040_Linux-x86-64_3of7.zip</a></td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>Combo of OJVM Component 11.2.0.4.201020 DB PSU + GI PSU 11.2.0.4.201020</td>
<td>p31720783_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Combo of OJVM Component 11.2.0.4.200714 DB PSU + GI PSU 11.2.0.4.200714</td>
<td>p31326410_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF 11.2.0.4.200414 OJVM PSU GIPSU 11.2.0.4.200414</td>
<td>p30783890_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GRID INFRASTRUCTURE PATCH SET UPDATE 11.2.0.4.200114</td>
<td>p30501155_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GRID INFRASTRUCTURE PATCH SET UPDATE 11.2.0.4.191015</td>
<td>p30070097_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GRID INFRASTRUCTURE PATCH SET UPDATE 11.2.0.4.190716</td>
<td>p29698727_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GRID INFRASTRUCTURE PATCH SET UPDATE 11.2.0.4.190416</td>
<td>p29255947_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Combo OJVM PSU 11.2.0.4.190416 and Database PSU 11.2.0.4.190416 patch
29252186 for Linux x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80112040&patchId=29252186&languageId=0&platformId=226">p29252186_112040_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td></td>
<td></td>
<td>GI PSU 11.2.0.4.190416 patch 29255947 for Linux x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80112040&patchId=29255947&languageId=0&platformId=226">p29255947_112040_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td></td>
<td></td>
<td>RC SCRIPTS (/ETC/RC.D/RC.* , /ETC/INIT.D/* ) ON OL7 FOR CLUSTERWARE (Patch)
patch 18370031 for Linux x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000007588&patchId=18370031&languageId=0&platformId=226">p18370031_112040_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td></td>
<td></td>
<td>OPatch Utility</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80112000&patchId=6880880&languageId=0&platformId=226">p6880880_112000_Linux-x86-64.zip</a></td>
</tr>
</tbody>
</table>

If the required software components are not properly downloaded and staged, the
toolkit will fail.

### Staging the Oracle installation media

You can stage the Oracle installation media in any one of the following
repository types:

- A [Cloud Storage](https://cloud.google.com/storage/docs/introduction) bucket.
- [Cloud Storage FUSE](https://cloud.google.com/storage/docs/gcs-fuse), an open
  source [FUSE](http://fuse.sourceforge.net/) adapter that allows you to mount
  Cloud Storage buckets as file systems on Linux or macOS systems.
- A network NFS share.

#### Cloud Storage bucket

To use a Cloud Storage bucket to stage your installation media, you need the
`gsutil` tool installed on your control node. The [`gsutil` tool](https://cloud.google.com/storage/docs/gsutil)
is a Python application that lets you access Cloud Storage from the command
line. To get the `gsutil` tool, install the [Cloud
SDK](https://cloud.google.com/sdk/docs).

#### Cloud Storage FUSE

With Cloud Storage FUSE, you can also pass the location of a Cloud Storage
service account json file. This is useful if your control node doesn't have a
proper instance service account. You should also confirm that the service
account scopes allow you to use Cloud Storage.

To create a new service account:

1. Navigate to your Google Cloud Console.
1. Select the **IAM & Admin** tab > **Service accounts**.
1. Click on **Create Service Account** and chose a relevant name.
1. Select a role that provides the permission that you need, such as
   **Storage Admin**.
1. Click on the "Create Key" button, and download the file in JSON format.

You can then pass the file as a parameter to the deployment:

```bash
--ora-swlib-type gcsfuse --ora-swlib-bucket oracle-swlib --ora-swlib-credentials ~/path_to/service_account.json
```

The toolkit uploads the service account to the server so that Cloud Storage FUSE
can use it.

#### NFS share

When you use an NFS share, you specify the NFS mount point on the
`ora-swlib-bucket` parameter:

```bash
--ora-swlib-type nfs --ora-swlib-bucket 192.168.0.250:/my_nfs_export
```

### Validating Media

You can validate that you have correctly staged all of the required installation
files by using the `check-swlib.sh` script, which validates the files based
on name, size, and MD5 message digest. To validate the media, specify the GCS
software bucket where the software is staged and the Oracle software version
that you are installing. The version default is 19.3.0.0.0.

Example of a successful media validation:

```bash
$ ./check-swlib.sh --ora-swlib-bucket gs://oracle-software --ora-version 19.3.0.0.0

Running with parameters from command line or environment variables:

ORA_SWLIB_BUCKET=gs://oracle-software
ORA_VERSION=19.3.0.0.0

Found V982063-01.zip : Oracle Database 19.3.0.0.0 for Linux x86-64
        file size matches (3059705302), md5 matches (1858bd0d281c60f4ddabd87b1c214a4f).

Found V982068-01.zip : Oracle Grid Infrastructure 19.3.0.0.0 for Linux x86-64
        file size matches (2889184573), md5 matches (b7c4c66f801f92d14faa0d791ccda721).

Found p29859737_190000_Linux-x86-64.zip : Oracle 19c DB RU patch 29859737 for Linux x86-64
        file size matches (498214157), md5 matches (3b017f517341df5b35e9fbd90f1f49aa).

Found p29800658_190000_Linux-x86-64.zip : Oracle 19c GI RU patch 29800658 for Linux x86-64
        file size matches (1365811472), md5 matches (13c0041a5ea7eb9fad4725d2136da627).

Found p29699097_190000_Linux-x86-64.zip : COMBO OF OJVM RU COMPONENT 19.4.0.0.190716 + GI RU 19.4.0.0.190716
        file size matches (1986870968), md5 matches (2206c8a2431eb6fa0c4f7dd5aa7a58b2).

Found p30133178_190000_Linux-x86-64.zip : COMBO OF OJVM RU COMPONENT 19.5.0.0.191015 GI RU 19.5.0.0.191015
        file size matches (2004604850), md5 matches (4189caeae850a7c4191fdd3fa4c0af6a).

Found p30463609_190000_Linux-x86-64.zip : COMBO OF OJVM RU COMPONENT 19.6.0.0.200114 GI RU 19.6.0.0.200114
        file size matches (2308492999), md5 matches (0b2f7ae16f623e8d26905ae7ba600b06).

Found p6880880_190000_Linux-x86-64.zip : OPatch Utility
        file size matches (111682884), md5 matches (ad583938cc58d2e0805f3f9c309e7431).
```

Example of a failed media validation:

```bash
$ ./check-swlib.sh --ora-swlib-bucket gs://oracle-software --ora-version 12.2.0.1.0
Running with parameters from command line or environment variables:

ORA_SWLIB_BUCKET=gs://oracle-software
ORA_VERSION=12.2.0.1.0

Found V839960-01.zip : Oracle Database 12.2.0.1.0 for Linux x86-64
        file size matches (3453696911), md5 matches (1841f2ce7709cf909db4c064d80aae79).

Found V840012-01.zip : Oracle Grid Infrastructure 12.2.0.1.0 for Linux x86-64 for Linux x86-64
        file size matches (2994687209), md5 matches (ac1b156334cc5e8f8e5bd7fcdbebff82).

Found p29252035_122010_Linux-x86-64.zip : Combo Of OJVM Update Component 12.2.0.1.190416 + DB Update 12.2.0.1.190416 patch 29252035 for Linux x86-64
        file size matches (514033994), md5 matches (1a645dd57d06795a966a8882cc59243e).

Found p29301687_122010_Linux-x86-64.zip : Grid Infrastructure Release Update 12.2.0.1.190416 patch 29301687 for Linux x86-64
        file size matches (1736326653), md5 matches (1648e66220987dae6ecd757bc9f424ba).

Found p25078431_122010_Linux-x86-64.zip : ACFS MODULE ORACLEACFS.KO FAILS TO LOAD ON OL7U3 SERVER WITH RHCK (Patch) patch 25078431 for Linux x86-64
        file size matches (537299043), md5 matches (84ad563860b583fdd052bca0dcc33939).

Object gs://oracle-software/p29252072_122010_Linux-x86-64.zip COMBO OF OJVM RU COMPONENT 12.2.0.1.190416 + 12.2.0.1.190416 GIAPR2019RU not found: CommandException: One or more URLs matched no objects.

Found p29699173_122010_Linux-x86-64.zip : COMBO OF OJVM RU COMPONENT 12.2.0.1.190716 + 12.2.0.1.190716 GIJUL2019RU
        file size matches (2096740052), md5 matches (d5955b2e975752d3cd164a3e7db9aaaf).

Found p30133386_122010_Linux-x86-64.zip : COMBO OF OJVM RU COMPONENT 12.2.0.1.191015 12.2.0.1.191015 GIOCT2019RU
        file size matches (1925393453), md5 matches (25c30defbcc6e470e574fb3e16abb1d2).

Found p30463673_122010_Linux-x86-64.zip : COMBO OF OJVM RU COMPONENT 12.2.0.1.200114 12.2.0.1.200114 GIJAN2020RU
        file size matches (2135739707), md5 matches (04e26701ecdf04898abe363cdbeaaa40).

Found p6880880_122010_Linux-x86-64.zip : OPatch Utility
        size does not match (remote: 118408624, expected: 111682884), md5 does not match (remote: b8e1367997544ab2790c5bcbe65ca805, expected: ad583938cc58d2e0805f3f9c309e7431).
```

## Prerequisite configuration

Before you run the tool you need to create JSON formatted configuration files
for the data mount devices and the ASM disk group.

### Data mount configuration file

In the data mount configuration file, you specify disk device attributes for:

- Oracle software installation, which is usually mounted at /u01
- Oracle diagnostic destination, which is usually mounted at /u02

In the configuration file, specify the block devices (actual devices, not
partitions), the mount point names, the file system types, and the mount options
in valid JSON format.

When you run the toolkit, specify the path to the configuration file by using
either the `--ora-data-mounts` command line option or the
`ORA_DATA_MOUNTS` environment variable. The file path can be relative or
fully qualified. The file name defaults to `data_mounts_config.json`.

The following example shows a properly formatted JSON data mount configuration
file:

```json
[
    {
        "purpose": "software",
        "blk_device": "/dev/mapper/3600a098038314352502b4f782f446138",
        "name": "u01",
        "fstype":"xfs",
        "mount_point":"/u01",
        "mount_opts":"defaults"
    },
    {
        "purpose": "diag",
        "blk_device": "/dev/mapper/3600a098038314352502b4f782f446230",
        "name": "u02",
        "fstype":"xfs",
        "mount_point":"/u02",
        "mount_opts":"defaults"
    }
]
```

### ASM disk group configuration file

In the ASM disk group configuration, specify the disk group names, the ASM disk
names, and the associated block devices (the actual devices, not partitions) in
valid JSON format.

When you run the toolkit, specify the path to the configuration file by using
either the  `--ora-asm-disks` command line option or the `ORA_ASM_DISKS`
environment variable. The file path can be relative or fully qualified. The file
name defaults to `ask_disk_config.json`.

The following example shows a properly formatted JSON ASM disk group
configuration file:

```json
[
    {
        "diskgroup": "DATA",
        "disks": [
            {
                "blk_device": "/dev/mapper/3600a098038314352502b4f782f446244",
                "name": "DATA1"
            },
            {
                "blk_device": "/dev/mapper/3600a098038314352502b4f782f446245",
                "name": "DATA2"
            }
        ]
    },
    {
        "diskgroup": "RECO",
        "disks": [
            {
                "blk_device": "/dev/mapper/3600a098038314352502b4f782f446246",
                "name": "RECO1"
            }
        ]
    }
]
```

### Specifying LVM logical volumes

In addition to the raw devices, you can also specify LVM logical volumes by
using the following format:

`"blk_device": "/dev/mapper/oracle-data"`

## Configuring Installations

You run the toolkit by using the `install-oracle.sh` shell script.

**IMPORTANT**: From the control node, run the toolkit shell scripts by using a
Linux user account that has the necessary SSH permissions and privileges on the
target database server(s).

You need to specify the Cloud Storage bucket that contains the Oracle software
and the backup destination for an initial RMAN backup. Running with the --help
argument displays the list of available options.

Although the toolkit provides defaults for just about everything, in most cases,
you need to customize your installation to some degree. Your customizations can
range from simple items, such as the name of a database or the associated
database edition, to less frequently adjusted items, such as ASM disk group
configurations. Regardless, the toolkit allows you to specify overrides for most
configuration parameters.

As well as creating the initial database, the toolkit implements and schedules a
simple RMAN backup script. You can adjust the backup parameters either before or
after running the toolkit, as required.

### Configuration defaults

Most parameters have default values, so you only need to specify them when you
need a different value. The parameter values that the toolkit uses are echoed
during execution so you can confirm the configuration.

The complete list of parameters and their values are provided in the [Parameters
section](#parameters).

### Oracle User Directories

The Oracle convention for naming of file system mounts is **_/pm_**, where
**_p_** is a string constant and **_m_** is a unique key, typically a two digit
integer. The standard string constant for Oracle user file system mounts is the
letter "u".

Following this convention, the toolkit creates the following default file system
mounts:

- **/u01** - For Oracle software. For example, /u01/app/oracle/product.

- **/u02** - For other Oracle files, including software staging and, optionally, the
  Oracle Automatic Diagnostic Repository (ADR).

You don't have to use a separate file system, physical device, or logical volume
for the software staging and other purposes. You can use the single file system,
/u01, or whatever you choose to call it, if you want to.

### Database backup configuration

As a part of installation, the toolkit creates an initial RMAN full database
backup, an archived redo log backup, and sets the initial backup schedule based
on your specifications or the default backup values.

The parameters for configuring your backups are described in [Backup
configuration parameters](#backup-configuration-parameters). The following list shows the
default backup configuration implemented by the toolkit:

- Backup scripts are stored in the directory `/home/oracle/scripts`.
- Associated log files are stored in the directory `/home/oracle/logs`.
- Weekly FULL database LEVEL=0 backups are run at 01:00 on Sundays.
- Daily FULL database LEVEL=1 cumulative incremental backups are run at
  01:00, Monday through Friday.
- Hourly archived redo log backups run at 30 minutes past every hour.
- RMAN backups are written to the Fast Recovery Area (FRA).

The toolkit schedules the backups by using the Linux cron utility under the
Oracle software owner user. You can run the backup scripts as necessary.

After installation is complete, you can adjust any of the attributes of the
backup scheme. You can also replace any and all parts of the initial backup
scheme or the backup script with your own scripts or backup tools.

### Parameters

The following sections document the parameters, organized by installation task
and then by the attribute that you use the parameter to specify.

Most attributes can be specified by using either an environment variable or a
command-line command. Environment variables are presented in capital letters.
Command-line commands are presented in lower case letters and are preceded by
two dashes.

You can specify parameters as either command line arguments or as predefined
environment variables.

Default values for the parameters are shown in bold letters.

#### Target environment parameters

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameter options</th>
<th>Range of Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>Target server IP address</td>
<td><p><pre>
INSTANCE_IP_ADDR
<br>
--instance-ip-addr
</pre></p>
</td>
<td>user defined - no default</td>
<td>The IP address of the target server to host the Oracle software and
database.<br>
Applicable for Oracle "single instance" installations.</td>
</tr>
<tr>
<td>Primary server IP address</td>
<td><p><pre>
PRIMARY_IP_ADDR
<br>
--primary-ip-addr
</pre></p>
</td>
<td>user defined - no default</td>
<td>The IP address of the primary server to use as source of primary database
for Data Guard configuration.<br>
Applicable for Oracle "single instance" installations.</td>
</tr>
<tr>
<td>Target server host name</td>
<td><p><pre>
INSTANCE_HOSTNAME
<br>
--instance-hostname
</pre></p>
</td>
<td>user defined<br>
INSTANCE_IP_ADDR</td>
<td>Optional hostname for the target server. Defaults to value of
INSTANCE_IP_ADDR. Specifying a hostname adds clarity to log and debug
files. </td>
</tr>
<tr>
<td>User on target server </td>
<td><p><pre>
INSTANCE_SSH_USER
<br>
--instance-ssh-user
</pre></p>
</td>
<td>user defined<br>
current user</td>
<td>Remote user with connectivity (including privilege escalation capabilities)
on target server.</td>
</tr>
<tr>
<td>Private key file for ssh connectivity to target server</td>
<td><p><pre>
INSTANCE_SSH_KEY
<br>
--instance-ssh-key
</pre></p>
</td>
<td>user defined<br>
~/.ssh/id_rsa</td>
<td></td>
</tr>
<tr>
<td>Ansible inventory file name</td>
<td><p><pre>
No environment variable
<br>
--inventory-file
</pre></p>
</td>
<td>user defined<br>
toolkit generated</td>
<td>Optional Ansible inventory file name. If not supplied, the toolkit
generates a filename.</td>
</tr>
</tbody>
</table>

#### Software installation parameters

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameters</th>
<th>Parameter Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>Oracle version</td>
<td><p><pre>
ORA_VERSION
--ora-version
</pre></p>
</td>
<td>19.3.0.0.0<br>
18.0.0.0.0<br>
12.2.0.1.0<br>
12.1.0.2.0<br>
11.2.0.4.0</td>
<td>All mainstream major releases.</td>
</tr>
<tr>
<td>Oracle edition</td>
<td><p><pre>
ORA_EDITION
--ora-edition
</pre></p>
</td>
<td>EE<br>
SE, for 11.2.0.4.0 only<br>
SE2, for 12.1.0.2.0 and above</td>
<td>SE or SE2 depending on the Oracle version chosen.</td>
</tr>
<tr>
<td>Software library type</td>
<td><p><pre>
ORA_SWLIB_TYPE
--ora-swlib-type
</pre></p>
</td>
<td>GCS<br>
GCSFUSE<br>
NFS</td>
<td>Remote storage type acting as a software library where the required
installation media is stored.</td>
</tr>
<tr>
<td>Software library location</td>
<td><p><pre>
ORA_SWLIB_BUCKET
--ora-swlib-bucket
</pre></p></td>
<td>user defined - no default<br>
Example: gs://oracle-software</td>
<td>GCS bucket where the required base software and patches have been
downloaded and staged.<br>
<br>
Only used when ORA_SWLIB_TYPE=GCS.</td>
</tr>
<tr>
<td>Software library path</td>
<td><p><pre>
ORA_SWLIB_PATH
--ora-swlib-path
</pre></p></td>
<td>user defined<br>
/u01/swlib</td>
<td>Path where the required base software and patches have been downloaded and
staged.<br>
<br>
Not used when ORA_SWLIB_TYPE=GCS.</td>
</tr>
<tr>
<td>Service account key file</td>
<td><p><pre>
ORA_SWLIB_CREDENTIALS
--ora-swlib-credentials
</pre></p></td>
<td>user defined - no default</td>
<td>Service account key file name. Only used when ORA_SWLIB_TYPE=GCSFUSE.</td>
</tr>
<tr>
<td>Storage configuration</td>
<td><br>
<p><pre>
ORA_DATA_MOUNTS
--ora-data-mounts
</pre></p></td>
<td>user defined<br>
data_mounts_config.json</td>
<td>Properly formatted JSON file providing mount and file system details for
local mounts including installation location for the Oracle software and
the location for Oracle diagnostic (ADR) directories. See <a
href="#data-mount-configuration-file">Data mount configuration file</a>.</td>
</tr>
<tr>
<td>Software unzip location</td>
<td><p><pre>
ORA_STAGING
--ora-staging
</pre></p></td>
<td>user defined<br>
ORA_SWLIB_PATH</td>
<td>Working area for unzipping and staging software and installation
files.<br>
<br>
Should have at least 16GB of available free space.</td>
</tr>
<tr>
<td>Listener Name</td>
<td><p><pre>
ORA_LISTENER_NAME
--ora-listener-name
</pre></p></td>
<td>user defined<br>
LISTENER</td>
<td></td>
</tr>
<tr>
<td>Listener Port</td>
<td><p><pre>
ORA_LISTENER_PORT
--ora-listener-port
</pre></p></td>
<td>user defined<br>
1521</td>
<td></td>
</tr>
<tr>
<td>Preferred NTP server</td>
<td><p><pre>
NTP_PREF
--ntp-pref
</pre></p></td>
<td>user defined - no default</td>
<td>Preferred NTP server to use in /etc/ntp.conf.<br>
<br>
Optional: set only if you need to manually define an NTP server, instead of
relying on the OS defaults.</td>
</tr>
<tr>
<td>Swap device</td>
<td><p><pre>
SWAP_BLK_DEVICE
--swap-blk-device
</pre></p></td>
<td>user defined - no default</td>
<td>Swap device to optionally create.<br>
<br>
Optional: set if you would like a swap partition and swap file created.</td>
</tr>
</tbody>
</table>

#### Storage configuration parameters

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameters</th>
<th>Parameter Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>ASM disk management</td>
<td><p><pre>
ORA_DISK_MGMT
--ora-disk-mgmt
</pre></p></td>
<td>asmlib<br>
udev</td>
<td>ASMlib option is applicable to Oracle Linux as RHEL implementation requires
Red Hat support. See MOS Doc ID: 1089399.1</td>
</tr>
<tr>
<td>Grid user role separation</td>
<td><p><pre>
ORA_ROLE_SEPARATION
--ora-role-separation
</pre></p></td>
<td>true<br>
false</td>
<td>Role separation means that the Grid Infrastructure is owned by the OS user
"grid" instead of the OS user "oracle".</td>
</tr>
<tr>
<td>Data disk group name</td>
<td><p><pre>
ORA_DATA_DISKGROUP
--ora-data-diskgroup
</pre></p></td>
<td>user defined<br>
DATA</td>
<td>Default disk group for DB files for initial database.</td>
</tr>
<tr>
<td>Reco disk group name</td>
<td><p><pre>
ORA_RECO_DISKGROUP
--ora-reco-diskgroup
</pre></p></td>
<td>user defined<br>
RECO</td>
<td>Default disk group for FRA files for initial database.</td>
</tr>
<tr>
<td>ASM disk configuration</td>
<td><p><pre>
ORA_ASM_DISKS
--ora-asm-disks
</pre></p></td>
<td>user defined<br>
asm_disk_config.json</td>
<td>Name of an ASM configuration file that contains ASM disk definitions in
valid JSON format. See <a href="#asm-disk-group-configuration-file">ASM disk group
configuration file</a>.</td>
</tr>
</tbody>
</table>

#### Database configuration parameters

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameters</th>
<th>Parameter Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>Database name</td>
<td><p><pre>
ORA_DB_NAME
--ora-db-name
</pre></p></td>
<td>user defined<br>
ORCL</td>
<td>Up to 8 characters. Must start with a letter. Other 7 characters can
include alphanumeric characters, underscore, number sign, and
dollar sign</td>
</tr>
<tr>
<td>Database domain</td>
<td><p><pre>
ORA_DB_DOMAIN
--ora-db-domain
</pre></p></td>
<td>user defined<br>
.world</td>
<td>String of name components up to 128 characters long including periods.</td>
</tr>
<tr>
<td>Character set</td>
<td><p><pre>
ORA_DB_CHARSET
--ora-db-charset
</pre></p></td>
<td>user defined<br>
AL32UTF8</td>
<td></td>
</tr>
<tr>
<td>National character set</td>
<td><p><pre>
ORA_DB_NCHARSET
--ora-db-ncharset
</pre></p></td>
<td>user defined<br>
AL16UTF16</td>
<td></td>
</tr>
<tr>
<td>Database compatibility setting</td>
<td><p><pre>
COMPATIBLE_RDBMS
--compatible-rdbms
</pre></p></td>
<td>user defined<br>
Oracle version</td>
<td>Defaults to the value of ORA_VERSION.</td>
</tr>
<tr>
<td>Container database</td>
<td><p><pre>
ORA_DB_CONTAINER
--ora-db-container
</pre></p></td>
<td>true<br>
false</td>
<td>Not applicable for release 11.2.0.4.</td>
</tr>
<tr>
<td>PDB name</td>
<td><p><pre>
ORA_PDB_NAME
--ora-pdb-name-prefix
</pre></p></td>
<td>PDB</td>
<td>Not applicable for release 11.2.0.4.</td>
</tr>
<tr>
<td>PDB count</td>
<td><p><pre>
ORA_PDB_COUNT
--ora-pdb-count
</pre></p></td>
<td>1</td>
<td>If greater than 1, a numeric is appended to each PDB name.<br>
<br>
The PDB count may have Oracle licensing implications.<br>
<br>
Not applicable for release 11.2.0.4.</td>
</tr>
<tr>
<td>Database type</td>
<td><p><pre>
ORA_DB_TYPE
--ora-db-type
</pre></p></td>
<td>MULTIPURPOSE<br>
DATA_WAREHOUSING<br>
OLTP</td>
<td></td>
</tr>
<tr>
<td>Redo log size</td>
<td><p><pre>
ORA_REDO_LOG_SIZE
--ora-redo-log-size
</pre></p></td>
<td>user defined<br>
100MB</td>
<td></td>
</tr>
</tbody>
</table>

#### RAC configuration parameters

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameters</th>
<th>Parameter Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>Cluster type</td>
<td><p><pre>
CLUSTER_TYPE
--cluster-type
</pre></p></td>
<td>
NONE<br>
RAC<br>
DG
</td>
<td>Specify "RAC" to install a RAC cluster. Use "DG" for standby installation. Otherwise a "Single Instance"
installation is performed.</td>
</tr>
<tr>
<td>RAC specific configuration parameters</td>
<td><p><pre>
CLUSTER_CONFIG
--cluster-config
</pre></p></td>
<td>user defined<br>
cluster_config.json</td>
<td>Used to specify the RAC scan listener name, port, IPs, and so forth. Also
used to list RAC nodes.<br>
<br>
Specifies a file containing properly formed JSON text.</td>
</tr>
</tbody>
</table>

#### Backup configuration parameters

<table>
<thead>
<tr>
<th>RMAN backup destination</th>
<th><p><pre>
BACKUP_DEST
--backup-dest
</pre></p></th>
<th>user defined - no default<br>
Example: +RECO</th>
<th>Disk group name or NFS file share location. Can include formatting options,
such as "/u02/db_backups/ORCL_%I_%T_%s_%p.bak", for example.<br>
<br>
When writing to a non-ASM disk group location, include a valid RMAN format
specification to ensure file name uniqueness, such as the example string
shown above.<br>
<br>
If you are writing to a local file system, the
directory does not have to exist, but initial backups will fail if the
destination is not available or writeable.</th>
</tr>
</thead>
<tbody>
<tr>
<td>RMAN full DB backup redundancy</td>
<td><p><pre>
BACKUP_REDUNDANCY
--backup-redundancy
</pre></p></td>
<td>user defined field<br>
2</td>
<td>An integer that specifies the number of full backups to keep.</td>
</tr>
<tr>
<td>RMAN archived redo log backup redundancy</td>
<td><p><pre>
ARCHIVE_REDUNDANCY
--archive-redundancy
</pre></p></td>
<td>user defined field<br>
2</td>
<td>An integer that specifies the number of times to redundantly backup
archived redo logs into an RMAN backup set.</td>
</tr>
<tr>
<td>Archived redo logs online retention days</td>
<td><p><pre>
ARCHIVE_ONLINE_DAYS
--archive-online-days
</pre></p></td>
<td>user defined field<br>
7</td>
<td>Archived redo logs are only deleted from disk when they are older than this
number of days.<br>
<br>
(And have been backed up with the specified redundancy.)</td>
</tr>
<tr>
<td>Day(s) of week for full DB backup (RMAN level=0)</td>
<td><p><pre>
BACKUP_LEVEL0_DAYS
--backup-level0-days
</pre></p></td>
<td>user defined<br>
0</td>
<td>Day(s) of week in cron format to be used for cron creation.</td>
</tr>
<tr>
<td>Day(s) of the week for incremental full DB backup (RMAN level=1)</td>
<td><p><pre>
BACKUP_LEVEL1_DAYS
--backup-level1-days
</pre></p></td>
<td>user defined<br>
1-6</td>
<td>Day(s) of week in cron format to be used for cron creation.</td>
</tr>
<tr>
<td>Start hour for RMAN full DB backups</td>
<td><p><pre>
BACKUP_START_HOUR
--backup-start-hour
</pre></p></td>
<td>user defined<br>
01</td>
<td>Hour in 24hour format.<br>
<br>
Used in cron for RMAN full (level=0 and level=1) backups.</td>
</tr>
<tr>
<td>Start minute for RMAN DB full backups</td>
<td><p><pre>
BACKUP_START_MIN
--backup-start-min
</pre></p></td>
<td>user defined<br>
00</td>
<td>Minute in XX format.<br>
<br>
Used in cron for RMAN full (level=0 and level=1) backups.</td>
</tr>
<tr>
<td>Start minute for archived redo log RMAN backups.</td>
<td><p><pre>
ARCHIVE_BACKUP_MIN
--archive-backup-min
</pre></p></td>
<td>user defined<br>
30</td>
<td>Minute in XX format.<br>
<br>
Used in cron for RMAN full (level=0 and level=1) backups.</td>
</tr>
<tr>
<td>Script location</td>
<td><p><pre>
BACKUP_SCRIPT_LOCATION
--backup-script-location
</pre></p></td>
<td>user defined<br>
/home/oracle/scripts</td>
<td>Location for storing the provided RMAN backup scripts and other provided
database scripts.<br>
<br>
Because only a handful of small text (.sh) files
are provided, the freespace requirements for this directory is
minimal.</td>
</tr>
<tr>
<td>Log file location</td>
<td><p><pre>
BACKUP_LOG_LOCATION
--backup-log-location
</pre></p></td>
<td>user defined<br>
/home/oracle/logs</td>
<td>Location for storing log and output files from the provided RMAN backup
scripts.<br>
<br>
Backup and log files are relatively small and hence the freespace
requirements for this directory is minimal.</td>
</tr>
</tbody>
</table>

#### Additional operational parameters

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameters</th>
<th>Parameter Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>Command help</td>
<td><p><pre>
--help
</pre></p></td>
<td></td>
<td>Display usage and all possible command line arguments.</td>
</tr>
<tr>
<td>Validate parameter definitions</td>
<td><p><pre>
--validate
</pre></p></td>
<td></td>
<td>Validate supplied parameters for such things as conformity to expected
input types and exit. Nothing is installed or changed on the target
server.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--check-instance
</pre></p></td>
<td></td>
<td>Run the "check-instance.yml" playbook only.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--prep-host
</pre></p></td>
<td></td>
<td>Run the "prep-host.yml" playbook only.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--install-sw
</pre></p></td>
<td></td>
<td>Run the "install-sw.yml" playbook only.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--no-patch
</pre></p></td>
<td></td>
<td>Install the base release, and do not apply patch set updates.  Use in conjunction with <a href="#patching">patching</a> functionality to apply patches post-installation.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--config-db
</pre></p></td>
<td></td>
<td>Run the "config-db.yml" playbook only.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--skip-database-config
</pre></p></td>
<td></td>
<td>Run all other playbooks but skip "config-db.yml", so that no database
instance is created.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--debug
</pre></p></td>
<td></td>
<td>Run with the Ansible debugging flag enabled.</td>
</tr>
</tbody>
</table>

### Example Toolkit Execution

In the following example, environment variables are used to specify the
following values:

-  The IP address of the target instance
-  The Oracle release
-  The database name

For all other parameters, the default values are accepted.

Note: Unless you specify a hostname on the INSTANCE_HOSTNAME environment
variable or the --instance-hostname command line argument, the target hostname
defaults to the target IP address.

```bash
$ export INSTANCE_IP_ADDR=10.150.0.42
$ export ORA_VERSION=19.3.0.0.0
$ export ORA_DB_NAME=PROD1
$ ./install-oracle.sh --ora-swlib-bucket gs://oracle-software --backup-dest +RECO

Inventory file for this execution: ./inventory_files/inventory_10.150.0.42_PROD1.

Running with parameters from command line or environment variables:

ANSIBLE_LOG_PATH=./logs/log_10.150.0.42_PROD1_20200610_160132.log
ARCHIVE_BACKUP_MIN=30
ARCHIVE_ONLINE_DAYS=7
ARCHIVE_REDUNDANCY=2
BACKUP_DEST=+RECO
BACKUP_LEVEL0_DAYS=0
BACKUP_LEVEL1_DAYS=1-6
BACKUP_LOG_LOCATION=/home/oracle/logs
BACKUP_REDUNDANCY=2
BACKUP_SCRIPT_LOCATION=/home/oracle/scripts
BACKUP_START_HOUR=01
BACKUP_START_MIN=00
CLUSTER_CONFIG=cluster_config.json
CLUSTER_TYPE=NONE
INSTANCE_HOSTGROUP_NAME=dbasm
INSTANCE_HOSTNAME=10.150.0.42
INSTANCE_IP_ADDR=10.150.0.42
INSTANCE_SSH_EXTRA_ARGS=''\''-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentityAgent=no'\'''
INSTANCE_SSH_KEY='~/.ssh/id_rsa'
INSTANCE_SSH_USER=goryunov
ORA_ASM_DISKS=asm_disk_config.json
ORA_DATA_DISKGROUP=DATA
ORA_DATA_MOUNTS=data_mounts_config.json
ORA_DB_CHARSET=AL32UTF8
ORA_DB_CONTAINER=TRUE
ORA_DB_DOMAIN=world
ORA_DB_NAME=PROD1
ORA_DB_NCHARSET=AL16UTF16
ORA_DB_TYPE=MULTIPURPOSE
ORA_DISK_MGMT=UDEV
ORA_EDITION=EE
ORA_LISTENER_NAME=LISTENER
ORA_LISTENER_PORT=1521
ORA_PDB_COUNT=1
ORA_PDB_NAME_PREFIX=PDB
ORA_RECO_DISKGROUP=RECO
ORA_REDO_LOG_SIZE=100MB
ORA_RELEASE=latest
ORA_ROLE_SEPARATION=TRUE
ORA_STAGING=/u01/swlib
ORA_SWLIB_BUCKET=gs://oracle-software
ORA_SWLIB_CREDENTIALS=
ORA_SWLIB_PATH=/u01/swlib
ORA_SWLIB_TYPE='""'
ORA_VERSION=19.3.0.0.0
PB_CHECK_INSTANCE=check-instance.yml
PB_CONFIG_DB=config-db.yml
PB_CONFIG_RAC_DB=config-rac-db.yml
PB_INSTALL_SW=install-sw.yml
PB_LIST='check-instance.yml prep-host.yml install-sw.yml config-db.yml'
PB_PREP_HOST=prep-host.yml
PRIMARY_IP_ADDR=

Ansible params:
Found Ansible at /usr/bin/ansible-playbook

Running Ansible playbook: /usr/bin/ansible-playbook -i ./inventory_files/inventory_10.150.0.42_PROD1 check-instance.yml

PLAY [all] ******************************************************************************************************************************************

TASK [Verify that Ansible on control node meets the version requirements] ***************************************************************************
ok: [10.150.0.42] => {
    "changed": false,
    "msg": "Ansible version is 2.9.9, continuing"
}

TASK [Test connectivity to target instance via ping] ************************************************************************************************
ok: [10.150.0.42]

TASK [Abort if ping module fails] *******************************************************************************************************************
ok: [10.150.0.42] => {
    "changed": false,
    "msg": "The instance has an usable python installation, continuing"
}

TASK [Collect facts from target] ********************************************************************************************************************
ok: [10.150.0.42]

... output truncated for brevity
```

In the following example, command-line arguments are used to specify the Oracle
Standard Edition and to create a non-container database.

```bash
$ ./install-oracle.sh --ora-edition SE2 --ora-db-container false \
 --ora-swlib-bucket gs://oracle-software --backup-dest +RECO \
 --instance-ip-addr 10.150.0.42

Inventory file for this execution: ./inventory_files/inventory_dbserver_ORCL.

Running with parameters from command line or environment variables:

ANSIBLE_LOG_PATH=./logs/log_dbserver_ORCL_20200610_161259.log
ARCHIVE_BACKUP_MIN=30
ARCHIVE_ONLINE_DAYS=7
ARCHIVE_REDUNDANCY=2
BACKUP_DEST=+RECO
BACKUP_LEVEL0_DAYS=0
BACKUP_LEVEL1_DAYS=1-6
BACKUP_LOG_LOCATION=/home/oracle/logs
BACKUP_REDUNDANCY=2
BACKUP_SCRIPT_LOCATION=/home/oracle/scripts
BACKUP_START_HOUR=01
BACKUP_START_MIN=00
CLUSTER_CONFIG=cluster_config.json
CLUSTER_TYPE=NONE
INSTANCE_HOSTGROUP_NAME=dbasm
INSTANCE_HOSTNAME=dbserver
INSTANCE_IP_ADDR=10.150.0.42
INSTANCE_SSH_EXTRA_ARGS=''\''-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentityAgent=no'\'''
INSTANCE_SSH_KEY='~/.ssh/id_rsa'
INSTANCE_SSH_USER=goryunov
ORA_ASM_DISKS=asm_disk_config.json
ORA_DATA_DISKGROUP=DATA
ORA_DATA_MOUNTS=data_mounts_config.json
ORA_DB_CHARSET=AL32UTF8
ORA_DB_CONTAINER=false
ORA_DB_DOMAIN=world
ORA_DB_NAME=ORCL
ORA_DB_NCHARSET=AL16UTF16
ORA_DB_TYPE=MULTIPURPOSE
ORA_DISK_MGMT=UDEV
ORA_EDITION=SE2
ORA_LISTENER_NAME=LISTENER
ORA_LISTENER_PORT=1521
ORA_PDB_COUNT=1
ORA_PDB_NAME_PREFIX=PDB
ORA_RECO_DISKGROUP=RECO
ORA_REDO_LOG_SIZE=100MB
ORA_RELEASE=latest
ORA_ROLE_SEPARATION=TRUE
ORA_STAGING=/u01/swlib
ORA_SWLIB_BUCKET=gs://oracle-software
ORA_SWLIB_CREDENTIALS=
ORA_SWLIB_PATH=/u01/swlib
ORA_SWLIB_TYPE='""'
ORA_VERSION=19.3.0.0.0
PB_CHECK_INSTANCE=check-instance.yml
PB_CONFIG_DB=config-db.yml
PB_CONFIG_RAC_DB=config-rac-db.yml
PB_INSTALL_SW=install-sw.yml
PB_LIST='check-instance.yml prep-host.yml install-sw.yml config-db.yml'
PB_PREP_HOST=prep-host.yml
PRIMARY_IP_ADDR=

Ansible params:
Found Ansible at /usr/bin/ansible-playbook

Running Ansible playbook: /usr/bin/ansible-playbook -i ./inventory_files/inventory_dbserver_19.3.0.0.0_ORCL   check-instance.yml

PLAY [all] ******************************************************************************************************************************************

TASK [Verify that Ansible on control node meets the version requirements] ***************************************************************************
ok: [dbserver] => {
    "changed": false,
    "msg": "Ansible version is 2.9.9, continuing"
}

TASK [Test connectivity to target instance via ping] ************************************************************************************************
ok: [dbserver]

TASK [Abort if ping module fails] *******************************************************************************************************************
ok: [dbserver] => {
    "changed": false,
    "msg": "The instance has an usable python installation, continuing"
}

TASK [Collect facts from target] ********************************************************************************************************************
ok: [dbserver]

... <output truncated for brevity>
```

The following example shows the error message that is received when an invalid
parameter is specified.

```bash
$ ./install-oracle.sh --ora-version=7.3.4 --ora-swlib-bucket gs://oracle-software --backup-dest +RECO
Incorrect parameter provided for ora-version: 7.3.4
```

## Post installation tasks

### Reset passwords

The Oracle toolkit does not use or store any passwords. At runtime, passwords
for the Oracle SYS and SYSTEM database users are set with strong, unique, and
randomized passwords that are not written to or persisted in any OS files.

Change the passwords immediately after running the toolkit.

To change the passwords, connect to the database by using a SYSDBA
administrative connection and change the passwords by using the SQL Plus
`password` command:

```bash
sqlplus / as sysdba

SQL> password SYSTEM
```

### Validate the environment

After deployment, you can validate your environment using several scripts that
are provided with the toolkit.

#### Listing Oracle ASM devices

You can list the devices that are used by Oracle ASM using the `asm_disks.sh`
script, as shown in the following example:

```bash
$ /home/oracle/scripts/asm_disks.sh
Disk device /dev/sdd1 may be an ASM disk - Disk name: DATA_0000
Disk device /dev/sde1 may be an ASM disk - Disk name: RECO_0000
Disk device /dev/sdf1 may be an ASM disk - Disk name: DEMO_0000
```

#### Displaying cluster resource status

You can generate a report that shows the Oracle Restart cluster resources by
using the `crs_check.sh` script, as shown in the following example:

```bash
$ /home/oracle/scripts/crs_check.sh

***** CRS STATUS *****

Oracle High Availability Services release version on the local node is [18.0.0.0.0]
Oracle High Availability Services version on the local node is [18.0.0.0.0]
CRS-4638: Oracle High Availability Services is online
CRS-4529: Cluster Synchronization Services is online

NAME=ora.DATA.dg
TYPE=ora.diskgroup.type
TARGET=ONLINE
STATE=ONLINE on db-host-1

... output truncated for brevity
```

#### Verify an Oracle cluster

You can verify the integrity of an Oracle cluster by using the
`cluvfy_checks.sh` script to run the Oracle Cluster Verify utility.

#### Oracle validation utilities

For a more comprehensive validation, use the utilities provided by Oracle
Support, which are available for download from My Oracle Support:

- [Autonomous Health Framework (AHF) - Including TFA and ORAchk/EXAChk (Doc ID 2550798.1)](https://support.oracle.com/epmos/faces/DocContentDisplay?id=2550798.1)

Oracle's Autonomous Health Framework (AHF) includes utilities such as Trace File
Analyzer (TFA). TFA provides options such as `tfactl summary`, which gives
a complete environment overview. AHF also includes a copy of ORAchk. Refer to
the Oracle documentation for more information.

The following example shows the use of the Oracle Cluster Verify utility:

```bash
$ /home/oracle/scripts/cluvfy_checks.sh

Verifying Oracle Restart Integrity ...PASSED

Verification of Oracle Restart integrity was successful.

CVU operation performed:      Oracle Restart integrity
Date:                         Jul 15, 2019 11:26:15 PM
CVU home:                     /u01/app/18.0.0/grid/
User:                         oracle

Verifying Physical Memory ...
  Node Name     Available                 Required                  Status
  ------------  ------------------------  ------------------------  ----------
  dbserver      14.5286GB (1.523434E7KB)  8GB (8388608.0KB)         passed
Verifying Physical Memory ...PASSED

... output truncated for brevity

Verifying Users With Same UID: 0 ...PASSED
Verifying Root user consistency ...
  Node Name                             Status
  ------------------------------------  ------------------------
  dbserver                              passed
Verifying Root user consistency ...PASSED

Verification of system requirement was successful.

CVU operation performed:      system requirement
Date:                         Jul 15, 2019 11:26:26 PM
CVU home:                     /u01/app/18.0.0/grid/
User:                         oracle
```

### Patching

You can apply Oracle Release Update (RU) or Patch Set Update (PSU) patches to
both the Grid Infrastructure and Database homes by using the
`apply-patch.sh` script of the toolkit.

By default, `install-oracle.sh` updates to the latest available patch.  To
apply a specific patch instead, use the `--no-patch` option in `install-oracle.sh`
to skip patching at installation time.  After installation is complete,  execute 
`apply-patch.sh` with the `--ora-release` option.  Specify the full release name including
timestamp;  a list of release names is available in
https://github.com/google/bms-toolkit/tree/master/roles/common/defaults/main.yml
under `gi-patches` and `rdbms-patches`.

A digest of the required patch files, including checksum hashes is provided in
the file `oracle-swlib.csv`.

To apply patches, you need to specify the location of the software library. You
can optionally specify the base database version, the release to patch to, the
database name, the staging location, and other optional parameters.

Example:

```bash
$ ./apply-patch.sh --help
        Usage: apply-patch.sh
         --ora-swlib-bucket <value>
         --inventory-file <value>
         [ --ora-version <value> ]
         [ --ora-release <value> ]
         [ --ora-swlib-path <value> ]
         [ --ora-staging <value> ]
         [ --ora-db-name <value> ]
         [ --help ]
         [ --validate ]
         -- [parameters sent to ansible]

$ ./apply-patch.sh \
  --ora-swlib-bucket gs://oracle-software \
  --ora-swlib-path /u02/oracle_install \
  --ora-staging /u02/oracle_install \
  --ora-version 19.3.0.0.0 \
  --ora-release 19.6.0.0.200114 \
    --inventory-file inventory_files/inventory_toolkit-db2_ORCL

Running with parameters from command line or environment variables:

ORA_DB_NAME=ORCL
ORA_RELEASE=19.6.0.0.200114
ORA_STAGING=/u02/oracle_install
ORA_SWLIB_BUCKET=gs://oracle-software
ORA_SWLIB_PATH=/u02/oracle_install
ORA_VERSION=19.3.0.0.0

Ansible params: -i inventory_files/inventory_toolkit-db2_ORCL
Found Ansible at /usr/bin/ansible-playbook
Running Ansible playbook: /usr/bin/ansible-playbook -i inventory_files/inventory_toolkit-db2_ORCL   patch.yml

PLAY [OPatch Restart patch] ****************************************************

TASK [Gathering Facts] *********************************************************
ok: [toolkit-db2]

TASK [Verify Ansible meets the version requirements] ********************************************************************************
ok: [toolkit-db2] => {
    "changed": false,
    "msg": "Ansible version is 2.9.6, continuing"
}

TASK [patch : Update OPatch in GRID_HOME]

... output truncated for brevity
```

### Patching RAC databases

The patching process for RAC databases is based on applying the OJVM+GI RU
"combo patches", which contain all necessary Release Update (RU) patches for
both the GI and RDBMS homes, as well as the Oracle Java Virtual Machine (OJVM)
database patches.

All GI patching is implemented using the `opatchauto` utility run by the root
user from the GI home and, therefore, if the GI and RDBMS homes are of the same
major release, patches both the GI and RDBMS homes in a single step.

By default, if RAC GI and RDBMS homes are of the same base release, the
**install-oracle.sh** script applies the latest RU/PSU patch to both.

You can skip all RU/PSU patching steps and install only the base software by
specifying the command line option `--no-patch`. You can then apply patches
separately later, either manually or by using the toolkit.

Alternatively, you can apply RAC GI and RDBMS patches independently from the
base software installations by using the script `apply-patch.sh`. This script
also allows you apply patches with more granularity.

The list of RU/PSU patches to apply are defined by the `gi_patches` and
`rdbms_patches` variables. By default, both are specified in the
`roles/common/defaults/main.yml` Ansible file. For each major Oracle release,
you can specify multiple versions from the various quarterly releases When you
install by using `install-oracle.sh`, the toolkit uses the most recent patch
version.

When creating a database, if the RDBMS home software is no longer at the base
release because it was patched during installation, the toolkit uses the Oracle
`datapatch` utility to apply patches at the database level, which is known as _SQL
level patching_.

#### BMS RAC install with latest RU

The following example RAC installation command applies the PSU/RU patches, which
is the default behavior:

```bash
./install-oracle.sh \
  --ora-swlib-bucket gs://oracle-software \
  --instance-ssh-key '~/.ssh/id_rsa' \
  --instance-ssh-user dba-user \
  --ora-swlib-path /u01/oracle_install \
  --ora-staging /u01/oracle_install \
  --backup-dest "+DATA" \
  --ora-version 19.3.0.0.0 \
  --ora-swlib-type gcs \
  --compatible-rdbms "11.2.0.4.0" \
  --ora-asm-disks bms_asm.json \
  --ora-data-mounts bms_mounts.json \
  --cluster-type RAC \
  --cluster-config bms_cluster.json \
  --ora-reco-diskgroup DATA \
  --ora-db-name ORCL
```

If you do not specify a value on the `--compatible-rdbms` parameter, the
RDBMS compatibility of the ASM disk group is set to the major version level
that is defined on the `--ora-version` parameter.

To patch RAC databases, the toolkit performs the following actions:

1. Stops the RAC databases in their homes by using the "stop home" option
   from the master node.
1. Stops TFA.
1. Kills the `asmcmd` daemon processes.
1. Executes `opatchauto apply`, patching both nodes.
1. Restarts the services, including `start home`.
1. On the master node only, runs the `datapatch` utility over several
   iterations to resolve any PDB invalid states.

Regardless of which script is used, the specifics about which patch files to
use, such as the file names of the source media, patch paths, and the software
versions, are taken from the `gi_patches` and `rdbms_patches` environment
variables. The defaults for these variables are defined in the
`roles/common/defaults/main.yml` Ansible file. You can override the default
values or specify patches that are not included in the
`roles/common/defaults/main.yml` file in a properly structured JSON file that
you reference on the `--extra-vars` Ansible argument.

The following example shows a YAML file that contains patch specifications for
both the GI and RDBMS software:

```yaml
gi_patches:
  - { category: "RU", base: "19.3.0.0.0", release: "19.7.0.0.200414", patchnum: "30783556", patchfile: "p30783556_190000_Linux-x86-64.zip", patch_subdir: "/30899722", prereq_check: FALSE, method: "opatchauto apply", ocm: FALSE, upgrade: FALSE }

rdbms_patches:
  - { category: "RU_Combo", base: "19.3.0.0.0", release: "19.7.0.0.200414", patchnum: "30783556", patchfile: "p30783556_190000_Linux-x86-64.zip", patch_subdir: "/30805684", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE }
```

The following example shows the specification of the YAML file by using the
**--extra-vars** Ansible parameter:

```bash
./install-oracle.sh \
  --ora-swlib-bucket gs://oracle-software \
  --instance-ssh-key '~/.ssh/id_rsa' \
  --instance-ssh-user dba-user \
  --ora-swlib-path /u01/oracle_install \
  --ora-staging /u01/oracle_install \
  --backup-dest "+DATA" \
  --ora-version 19.3.0.0.0 \
  --ora-swlib-type gcs \
  --compatible-rdbms "11.2.0.4.0" \
  --ora-asm-disks bms_asm.json
  --ora-data-mounts bms_mounts.json \
  --cluster-type RAC \
  --cluster-config bms_cluster.json \
  --ora-reco-diskgroup DATA \
  --ora-db-name ORCL \
  -- "--extra-vars @patches.yaml"
```

Note: you can use the `--extra-vars` Ansible parameter to specify other things
besides a JSON file that contains patch details, such as specifying other
optional or ad-hoc Ansible run-time parameters.

To apply additional granularity for patches when you use the `apply-patch.sh`
script use the `--ora-version` and `--ora-release` parameters to specify a
major Oracle version and a specific patch release level, respectively.

For example:

```bash
./apply-patch.sh \
  --ora-swlib-bucket gs://oracle-software \
  --inventory-file inventory_files/inventory_ORCL_RAC \
  --ora-version 19.3.0.0.0 \
  --ora-release 19.7.0.0.200414 \
  --ora-swlib-path /u01/oracle_install \
  --ora-staging /u01/oracle_install \
  --ora-db-name ORCL
  -- "--extra-vars @patches.yaml"
```

### Destructive Cleanup

If you need to uninstall the Oracle software, the Oracle software includes
uninstallation options, which are the recommended way to uninstall Oracle
software.

If necessary, you can use the script `cleanup-oracle.sh` to perform a
destructive or a brute-force clean-up of Oracle databases, services, and
software from a specified target database server. A brute-force clean-up takes
the following actions:

-  Kills all running Oracle services.
-  Deconfigures the Oracle Restart software.
-  Removes Oracle related directories and files.
-  Removes Oracle software owner users and groups.
-  Re-initializes ASM storage devices and uninstalls ASMlib if installed.
-  Reboots the server.

**Important**: a destructive cleanup permanently deletes the databases and any data they
contain. Any backups that are stored local to the server are also deleted. Backups
stored in Cloud Storage, Cloud Storage FUSE, or NFS devices are not affected by a
destructive cleanup.

**Recommendation**: provide a value for the role separation parameter, which
defaults to `TRUE`. On the `--inventory-file` parameter, specify the location
of the inventory file:

```bash
$ ./cleanup-oracle.sh --help
        Usage: cleanup-oracle.sh
          --ora-version <value>
          --inventory-file <value>
          --yes-i-am-sure
          [ --ora-role-separation <value> ]
          [ --ora-disk-mgmt <value> ]
          [ --ora-swlib-path <value> ]
          [ --ora-staging <value> ]
          [ --ora-asm-disks <value> ]
          [ --ora-data-mounts <value> ]
          [ --help ]
```

Sample usage:

```bash
$ ./cleanup-oracle.sh --ora-version 19 \
--inventory-file ./inventory_files/inventory_oracledb1_ORCL \
--yes-i-am-sure \
--ora-disk-mgmt udev \
--ora-swlib-path /u02/oracle_install \
--ora-staging /u02/oracle_install \
--ora-asm-disks asm_disk_config.json \
--ora-data-mounts data_mounts_config.json

Running with parameters from command line or environment variables:

INVENTORY_FILE=./inventory_files/inventory_oracledb1_ORCL
ORA_ASM_DISKS=asm_disk_config.json
ORA_DATA_MOUNTS=data_mounts_config.json
ORA_DISK_MGMT=udev
ORA_ROLE_SEPARATION=TRUE
ORA_STAGING=/u02/oracle_install
ORA_SWLIB_PATH=/u02/oracle_install
ORA_VERSION=19.3.0.0.0

Ansible params:
Found Ansible at /usr/bin/ansible-playbook

Running Ansible playbook: /usr/bin/ansible-playbook -i ./inventory_files/inventory_oracledb1_ORCL  brute-cleanup.yml

PLAY [all] ************************************************************************************
... output truncated for brevity
```
