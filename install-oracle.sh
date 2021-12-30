#!/bin/bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

echo Command used:
echo "$0 $@"
echo

#
#export ANSIBLE_LOG_PATH=~/ansible.log
#export ANSIBLE_DEBUG=True"
#
# Some variables
#
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
skip_compatible_rdbms="false"
#
# Playbooks
#
PB_CHECK_INSTANCE="check-instance.yml"
     PB_PREP_HOST="prep-host.yml"
    PB_INSTALL_SW="install-sw.yml"
     PB_CONFIG_DB="config-db.yml"
 PB_CONFIG_RAC_DB="config-rac-db.yml"
#
# These playbooks must exist
#
for PBOOK in "${PB_CHECK_INSTANCE}" "${PB_PREP_HOST}" "${PB_INSTALL_SW}" "${PB_CONFIG_DB}"; do
  if [[ ! -f "${PBOOK}" ]]; then
    printf "\n\033[1;31m%s\033[m\n\n" "The playbook ${PBOOK} does not exist; cannot continue."
    exit 126
  else
    if [[ -z "${PB_LIST}" ]]; then
      PB_LIST="${PBOOK}"
    else
      PB_LIST="${PB_LIST} ${PBOOK}"
    fi
  fi
done
#
# Inventory file (used to run the playbooks)
#
INVENTORY_DIR="./inventory_files"  # Where to save the inventory files
INVENTORY_FILE="${INVENTORY_DIR}/inventory"  # Default, the whole name will be built later using some parameters
INSTANCE_HOSTGROUP_NAME="dbasm"  # Constant used for both SI and RAC installations
#
if [[ ! -d "${INVENTORY_DIR}" ]]; then
  mkdir -p "${INVENTORY_DIR}"
  if [ $? -eq 0 ]; then
    printf "\n\033[1;36m%s\033[m\n\n" "Successfully created the ${INVENTORY_DIR} directory to save the inventory files."
  else
    printf "\n\033[1;31m%s\033[m\n\n" "Unable to create the ${INVENTORY_DIR} directory to save the inventory files; cannot continue."
    exit 123
  fi
fi
#
# Ansible logs directory, the logfile name is created later one
#
 LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/log"
if [[ ! -d "${LOG_DIR}" ]]; then
  mkdir -p "${LOG_DIR}"
  if [ $? -eq 0 ]; then
    printf "\n\033[1;36m%s\033[m\n\n" "Successfully created the ${LOG_DIR} directory to save the ansible logs."
  else
    printf "\n\033[1;31m%s\033[m\n\n" "Unable to create the ${LOG_DIR} directory to save the ansible logs; cannot continue."
    exit 123
  fi
fi

shopt -s nocasematch

# Check if we're using the Mac stock getopt and fail if true
out=`getopt -T`
if [ $? != 4 ]; then
  echo -e "Your getopt does not support long parametrs, possibly you're on a Mac, if so please install gnu-getopt with brew"
  echo -e "\thttps://brewformulas.org/Gnu-getopt"
  exit
fi

ORA_VERSION="${ORA_VERSION:-19.3.0.0.0}"
ORA_VERSION_PARAM='^(19\.3\.0\.0\.0|18\.0\.0\.0\.0|12\.2\.0\.1\.0|12\.1\.0\.2\.0|11\.2\.0\.4\.0)$'

ORA_RELEASE="${ORA_RELEASE:-latest}"
ORA_RELEASE_PARAM="^(base|latest|[0-9]{,2}\.[0-9]{,2}\.[0-9]{,2}\.[0-9]{,2}\.[0-9]{,6})$"

ORA_EDITION="${ORA_EDITION:-EE}"
ORA_EDITION_PARAM="^(EE|SE|SE2)$"

CLUSTER_TYPE="${CLUSTER_TYPE:-NONE}"
CLUSTER_TYPE_PARAM="NONE|RAC|DG"

ORA_SWLIB_BUCKET="${ORA_SWLIB_BUCKET}"
ORA_SWLIB_BUCKET_PARAM="^.+[^/]"

ORA_SWLIB_TYPE="${ORA_SWLIB_TYPE:-GCS}"
ORA_SWLIB_TYPE_PARAM="^(\"\"|GCS|GCSFUSE|NFS)$"

ORA_SWLIB_PATH="${ORA_SWLIB_PATH:-/u01/swlib}"
ORA_SWLIB_PATH_PARAM="^/.*"

ORA_SWLIB_CREDENTIALS="${ORA_SWLIB_CREDENTIALS}"
ORA_SWLIB_CREDENTIALS_PARAM=".*"

ORA_STAGING="${ORA_STAGING:-""}"
ORA_STAGING_PARAM="^/.+$"

ORA_LISTENER_NAME="${ORA_LISTENER_NAME:-LISTENER}"
ORA_LISTENER_NAME_PARAM="^[a-zA-Z0-9]+$"

ORA_LISTENER_PORT="${ORA_LISTENER_PORT:-1521}"
ORA_LISTENER_PORT_PARAM="^[0-9]+$"

ORA_DB_NAME="${ORA_DB_NAME:-ORCL}"
ORA_DB_NAME_PARAM="^[a-zA-Z0-9_$]+$"

ORA_DB_DOMAIN="${ORA_DB_DOMAIN}"
ORA_DB_DOMAIN_PARAM="^[a-zA-Z0-9]*$"

ORA_DB_CHARSET="${ORA_DB_CHARSET:-AL32UTF8}"
ORA_DB_CHARSET_PARAM="^.+$"

ORA_DB_NCHARSET="${ORA_DB_NCHARSET:-AL16UTF16}"
ORA_DB_NCHARSET_PARAM="^.+$"

ORA_DB_CONTAINER="${ORA_DB_CONTAINER:-TRUE}"
ORA_DB_CONTAINER_PARAM="^(TRUE|FALSE)$"

ORA_DB_TYPE="${ORA_DB_TYPE:-MULTIPURPOSE}"
ORA_DB_TYPE_PARAM="MULTIPURPOSE|DATA_WAREHOUSING|OLTP"

ORA_PDB_NAME_PREFIX="${ORA_PDB_NAME_PREFIX:-PDB}"
ORA_PDB_NAME_PREFIX_PARAM="^[a-zA-Z0-9]+$"

ORA_PDB_COUNT="${ORA_PDB_COUNT:-1}"
ORA_PDB_COUNT_PARAM="^[0-9]+"

ORA_REDO_LOG_SIZE="${ORA_REDO_LOG_SIZE:-100MB}"
ORA_REDO_LOG_SIZE_PARAM="^[0-9]+MB$"

ORA_DISK_MGMT="${ORA_DISK_MGMT:-UDEV}"
ORA_DISK_MGMT_PARAM="ASMLIB|UDEV"

ORA_ROLE_SEPARATION="${ORA_ROLE_SEPARATION:-TRUE}"
ORA_ROLE_SEPARATION_PARAM="^(TRUE|FALSE)$"

ORA_DATA_DISKGROUP="${ORA_DATA_DISKGROUP:-DATA}"
ORA_DATA_DISKGROUP_PARAM="^[a-zA-Z0-9]+$"

ORA_RECO_DISKGROUP="${ORA_RECO_DISKGROUP:-RECO}"
ORA_RECO_DISKGROUP_PARAM="^[a-zA-Z0-9]+$"

ORA_ASM_DISKS="${ORA_ASM_DISKS:-asm_disk_config.json}"
ORA_ASM_DISKS_PARAM="^.*$"

ORA_DATA_MOUNTS="${ORA_DATA_MOUNTS:-data_mounts_config.json}"
ORA_DATA_MOUNTS_PARAM="^.*$"

CLUSTER_CONFIG="${CLUSTER_CONFIG:-cluster_config.json}"
CLUSTER_CONFIG_PARAM="^.*$"

BACKUP_DEST="${BACKUP_DEST}"
BACKUP_DEST_PARAM="^(\/|\+).*$"

BACKUP_REDUNDANCY="${BACKUP_REDUNDANCY:-2}"
BACKUP_REDUNDANCY_PARAM="^[0-9]+$"

ARCHIVE_REDUNDANCY="${ARCHIVE_REDUNDANCY:-2}"
ARCHIVE_REDUNDANCY_PARAM="^[0-9]+$"

ARCHIVE_ONLINE_DAYS="${ARCHIVE_ONLINE_DAYS:-7}"
ARCHIVE_ONLINE_DAYS_PARAM="^[0-9]+$"

BACKUP_LEVEL0_DAYS="${BACKUP_LEVEL0_DAYS:-0}"
BACKUP_LEVEL0_DAYS_PARAM="^[0-6]-?[0-6]?$"

BACKUP_LEVEL1_DAYS="${BACKUP_LEVEL1_DAYS:-1-6}"
BACKUP_LEVEL1_DAYS_PARAM="^[0-6]-?[0-6]?$"

BACKUP_START_HOUR="${BACKUP_START_HOUR:-01}"
BACKUP_START_HOUR_PARAM="^(2[0-3]|[01]?[0-9])$"

BACKUP_START_MIN="${BACKUP_START_MIN:-00}"
BACKUP_START_MIN_PARAM="^[0-5][0-9]$"

ARCHIVE_BACKUP_MIN="${ARCHIVE_BACKUP_MIN:-30}"
ARCHIVE_BACKUP_MIN_PARAM="^[0-5][0-9]$"

BACKUP_SCRIPT_LOCATION="${BACKUP_SCRIPT_LOCATION:-/home/oracle/scripts}"
BACKUP_SCRIPT_LOCATION_PARAM="^/.+$"

BACKUP_LOG_LOCATION="${BACKUP_LOG_LOCATION:-/home/oracle/logs}"
BACKUP_LOG_LOCATION_PARAM="^/.+$"

INSTANCE_IP_ADDR="${INSTANCE_IP_ADDR}"
INSTANCE_IP_ADDR_PARAM='^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'

PRIMARY_IP_ADDR="${PRIMARY_IP_ADDR}"
PRIMARY_IP_ADDR_PARAM='^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'

INSTANCE_SSH_USER="${INSTANCE_SSH_USER:-`whoami`}"
INSTANCE_SSH_USER_PARAM="^[a-z0-9]+$"

INSTANCE_HOSTNAME="${INSTANCE_HOSTNAME:-${INSTANCE_IP_ADDR}}"
INSTANCE_HOSTNAME_PARAM="^[a-z0-9]+$"

INSTANCE_SSH_KEY="${INSTANCE_SSH_KEY:-~/.ssh/id_rsa}"
INSTANCE_SSH_KEY_PARAM="^.+$"

INSTANCE_SSH_EXTRA_ARGS="${INSTANCE_SSH_EXTRA_ARGS:-'-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentityAgent=no'}"
INSTANCE_SSH_EXTRA_ARGS_PARAM="^/.+$"

NTP_PREF="${NTP_PREF}"
NTP_PREF_PARAM=".*"

SWAP_BLK_DEVICE="${SWAP_BLK_DEVICE}"
SWAP_BLK_DEVICE_PARAM=".*"

COMPATIBLE_RDBMS="${COMPATIBLE_RDBMS:-0}"
COMPATIBLE_RDBMS_PARAM="^[0-9][0-9]\.[0-9].*"

export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false
###
GETOPT_MANDATORY="ora-swlib-bucket:"
GETOPT_OPTIONAL="backup-dest:,ora-version:,no-patch,ora-edition:,cluster-type:,cluster-config:,ora-staging:,ora-db-name:,ora-db-domain:,ora-db-charset:,ora-disk-mgmt:,ora-role-separation:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,ora-data-diskgroup:,ora-reco-diskgroup:,ora-asm-disks:,ora-data-mounts:,ora-listener-port:,ora-listener-name:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,ora-db-ncharset:,ora-db-container:,ora-db-type:,ora-pdb-name-prefix:,ora-pdb-count:,ora-redo-log-size:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,backup-redundancy:,archive-redundancy:,archive-online-days:,backup-level0-days:,backup-level1-days:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,backup-start-hour:,backup-start-min:,archive-backup-min:,backup-script-location:,backup-log-location:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,ora-swlib-type:,ora-swlib-path:,ora-swlib-credentials:,instance-ip-addr:,primary-ip-addr:,instance-ssh-user:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,instance-ssh-key:,instance-hostname:,ntp-pref:,inventory-file:,compatible-rdbms:,instance-ssh-extra-args:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,help,validate,check-instance,prep-host,install-sw,config-db,debug,allow-install-on-vm,skip-database-config"
GETOPT_LONG="$GETOPT_MANDATORY,$GETOPT_OPTIONAL"
GETOPT_SHORT="h"

VALIDATE=0

options=$(getopt --longoptions "$GETOPT_LONG" --options "$GETOPT_SHORT" -- "$@")

[ $? -eq 0 ] || {
  echo "Invalid options provided: $*"
  exit 1
}

eval set -- "$options"

while true; do
  case "$1" in
  --ora-version)
    ORA_VERSION="$2"
    if [[ "${ORA_VERSION}" = "19" ]]   ; then ORA_VERSION="19.3.0.0.0"; fi
    if [[ "${ORA_VERSION}" = "18" ]]   ; then ORA_VERSION="18.0.0.0.0"; fi
    if [[ "${ORA_VERSION}" = "12" ]]   ; then ORA_VERSION="12.2.0.1.0"; fi
    if [[ "${ORA_VERSION}" = "12.2" ]] ; then ORA_VERSION="12.2.0.1.0"; fi
    if [[ "${ORA_VERSION}" = "12.1" ]] ; then ORA_VERSION="12.1.0.2.0"; fi
    if [[ "${ORA_VERSION}" = "11" ]]   ; then ORA_VERSION="11.2.0.4.0"; fi
    shift;
    ;;
  --no-patch)
    ORA_RELEASE="base"
    ;;
  --ora-edition)
    ORA_EDITION="$(echo $2| tr 'a-z' 'A-Z')"
    shift;
    ;;
  --cluster-type)
    CLUSTER_TYPE="$(echo $2| tr 'a-z' 'A-Z')"
    shift;
    ;;
  --inventory-file)
    INVENTORY_FILE_PARAM="$2"
    shift;
    ;;
  --compatible-rdbms)
    COMPATIBLE_RDBMS="$2"
    shift;
    ;;
  --ora-swlib-bucket)
    ORA_SWLIB_BUCKET="$2"
    shift;
    ;;
  --ora-swlib-type)
    ORA_SWLIB_TYPE="$2"
    shift;
    ;;
  --ora-swlib-path)
    ORA_SWLIB_PATH="$2"
    shift;
    ;;
  --ora-swlib-credentials)
    ORA_SWLIB_CREDENTIALS="$2"
    shift;
    ;;
  --ora-staging)
    ORA_STAGING="$2"
    shift;
    ;;
  --ora-db-name)
    ORA_DB_NAME="$2"
    shift;
    ;;
  --ora-db-domain)
    ORA_DB_DOMAIN="$2"
    shift;
    ;;
  --ora-db-charset)
    ORA_DB_CHARSET="$2"
    shift;
    ;;
  --ora-db-ncharset)
    ORA_DB_NCHARSET="$2"
    shift;
    ;;
  --ora-disk-mgmt)
    ORA_DISK_MGMT="$2"
    shift;
    ;;
  --ora-role-separation)
    ORA_ROLE_SEPARATION="$2"
    shift;
    ;;
  --ora-data-diskgroup)
    ORA_DATA_DISKGROUP="$2"
    shift;
    ;;
  --ora-reco-diskgroup)
    ORA_RECO_DISKGROUP="$2"
    shift;
    ;;
  --ora-asm-disks)
    ORA_ASM_DISKS="$2"
    shift;
    ;;
  --ora-data-mounts)
    ORA_DATA_MOUNTS="$2"
    shift;
    ;;
  --cluster-config)
    CLUSTER_CONFIG="$2"
    shift;
    ;;
  --ora-listener-port)
    ORA_LISTENER_PORT="$2"
    shift;
    ;;
  --ora-listener-name)
    ORA_LISTENER_NAME="$2"
    shift;
    ;;
  --ora-db-container)
    ORA_DB_CONTAINER="$2"
    shift;
    ;;
  --ora-db-type)
    ORA_DB_TYPE="$2"
    shift;
    ;;
  --ora-pdb-name-prefix)
    ORA_PDB_NAME_PREFIX="$2"
    shift;
    ;;
  --ora-pdb-count)
    ORA_PDB_COUNT="$2"
    shift;
    ;;
  --ora-redo-log-size)
    ORA_REDO_LOG_SIZE="$2"
    shift;
    ;;
  --backup-dest)
    BACKUP_DEST="$2"
    shift;
    ;;
  --backup-redundancy)
    BACKUP_REDUNDANCY="$2"
    shift;
    ;;
  --archive-redundancy)
    ARCHIVE_REDUNDANCY="$2"
    shift;
    ;;
  --archive-online-days)
    ARCHIVE_ONLINE_DAYS="$2"
   shift;
    ;;
  --backup-level0-days)
    BACKUP_LEVEL0_DAYS="$2"
    shift;
    ;;
  --backup-level1-days)
    BACKUP_LEVEL1_DAYS="$2"
    shift;
    ;;
  --backup-start-hour)
    BACKUP_START_HOUR="$2"
    shift;
    ;;
  --backup-start-min)
    BACKUP_START_MIN="$2"
    shift;
    ;;
  --archive-backup-min)
    ARCHIVE_BACKUP_MIN="$2"
    shift;
    ;;
  --backup-script-location)
    BACKUP_SCRIPT_LOCATION="$2"
    shift;
    ;;
  --backup-log-location)
    BACKUP_LOG_LOCATION="$2"
    shift;
    ;;
  --instance-ip-addr)
    INSTANCE_IP_ADDR="$2"
    shift;
    ;;
  --primary-ip-addr)
    PRIMARY_IP_ADDR="$2"
    shift;
    ;;
  --instance-ssh-key)
    INSTANCE_SSH_KEY="$2"
    shift;
    ;;
  --instance-hostname)
    INSTANCE_HOSTNAME="$2"
    shift;
    ;;
  --instance-ssh-user)
    INSTANCE_SSH_USER="$2"
    shift;
    ;;
  --instance-ssh-extra-args)
    INSTANCE_SSH_EXTRA_ARGS="$2"
    shift;
    ;;
  --ntp-pref)
    NTP_PREF="$2"
    shift;
    ;;
  --swap-blk-device)
    SWAP_BLK_DEVICE="$2"
    shift;
    ;;
  --check-instance)
    PARAM_PB_CHECK_INSTANCE="${PB_CHECK_INSTANCE}"
    ;;
  --prep-host)
    PARAM_PB_PREP_HOST="${PB_PREP_HOST}"
    ;;
  --install-sw)
    PARAM_PB_INSTALL_SW="${PB_INSTALL_SW}"
    ;;
  --config-db)
    PARAM_PB_CONFIG_DB="${PB_CONFIG_DB}"
    ;;
  --debug)
    export ANSIBLE_DEBUG=1
    export ANSIBLE_DISPLAY_SKIPPED_HOSTS=true
    ;;
  --allow-install-on-vm)
    ANSIBLE_PARAMS="${ANSIBLE_PARAMS} -e allow_install_on_vm=true"
    ;;
  --skip-database-config)
    PB_LIST="${PB_CHECK_INSTANCE} ${PB_PREP_HOST} ${PB_INSTALL_SW}"
    ;;
  --validate)
    VALIDATE=1
    ;;
  --help|-h)
    echo -e "\tUsage: `basename $0` "
    echo $GETOPT_MANDATORY|sed 's/,/\n/g'|sed 's/:/ <value>/'|sed 's/\(.\+\)/\t --\1/'
    echo $GETOPT_OPTIONAL |sed 's/,/\n/g'|sed 's/:/ <value>/'|sed 's/\(.\+\)/\t [ --\1 ]/'
    echo -e "\t -- [parameters sent to ansible]"
    exit 2
    ;;
  --)
    shift
    break
    ;;
  esac
  shift
done
#
# Build the playbook list to execute depending on the command line option if specified
#
for PARAM in "${PARAM_PB_CHECK_INSTANCE}" "${PARAM_PB_PREP_HOST}" "${PARAM_PB_INSTALL_SW}" "${PARAM_PB_CONFIG_DB}"; do
  if [[ -n "${PARAM}" ]]; then
    PARAM_PB_LIST="${PARAM_PB_LIST} ${PARAM}"
  fi
done
if [[ -n "${PARAM_PB_LIST}" ]]; then
  PB_LIST="${PARAM_PB_LIST}"
fi
#
# Parameter defaults
#
[[ "$ORA_STAGING" == "" ]] && {
    ORA_STAGING=$ORA_SWLIB_PATH
}
[[ "$COMPATIBLE_RDBMS" == "0" ]] && {
    COMPATIBLE_RDBMS=$ORA_VERSION
}
#
# Variables verification
#
shopt -s nocasematch

[[ ! "$ORA_VERSION" =~ $ORA_VERSION_PARAM ]] && {
    echo "Incorrect parameter provided for ora-version: $ORA_VERSION"
    exit 1
}
[[ ! "$ORA_EDITION" =~ $ORA_EDITION_PARAM ]] && {
    echo "Incorrect parameter provided for ora-edition: $ORA_EDITION"
    exit 1
}
[[ ! "$ORA_EDITION" =~ "EE" ]] && [[ "$CLUSTER_TYPE" =~ "DG" ]] && {
  echo "ora-edition should be EE with cluster-type DG"
  exit 1
}
[[ ! "$CLUSTER_TYPE" =~ $CLUSTER_TYPE_PARAM ]] && {
    echo "Incorrect parameter provided for cluster-type: $CLUSTER_TYPE"
    exit 1
}
[[ ! "$ORA_SWLIB_BUCKET" =~ $ORA_SWLIB_BUCKET_PARAM ]] && {
    echo "Incorrect parameter provided for ora-swlib-bucket: $ORA_SWLIB_BUCKET"
    echo "Example: gs://my-gcs-bucket"
    exit 1
}
[[ ! "$ORA_SWLIB_TYPE" =~ $ORA_SWLIB_TYPE_PARAM ]] && {
    echo "Incorrect parameter provided for ora-swlib-type: $ORA_SWLIB_TYPE"
    exit 1
}
[[ ! "$ORA_SWLIB_PATH" =~ $ORA_SWLIB_PATH_PARAM ]] && {
    echo "Incorrect parameter provided for ora-swlib-path: $ORA_SWLIB_PATH"
    exit 1
}
[[ ! "$ORA_SWLIB_CREDENTIALS" =~ $ORA_SWLIB_CREDENTIALS_PARAM ]] && {
    echo "Incorrect parameter provided for ora-swlib-credentials: $ORA_SWLIB_CREDENTIALS"
    exit 1
}
[[ ! "$ORA_STAGING" =~ $ORA_STAGING_PARAM ]] && {
    echo "Incorrect parameter provided for ora-staging: $ORA_STAGING"
    exit 1
}
[[ ! "$ORA_DB_NAME" =~ $ORA_DB_NAME_PARAM ]] && {
    echo "Incorrect parameter provided for ora-db-name: $ORA_DB_NAME"
    exit 1
}
[[ ! "$ORA_DB_DOMAIN" =~ $ORA_DB_DOMAIN_PARAM ]] && {
    echo "Incorrect parameter provided for ora-db-domain: $ORA_DB_DOMAIN"
    exit 1
}
[[ ! "$ORA_DB_CHARSET" =~ $ORA_DB_CHARSET_PARAM ]] && {
    echo "Incorrect parameter provided for ora-db-charset: $ORA_DB_CHARSET"
    exit 1
}
[[ ! "$ORA_DB_NCHARSET" =~ $ORA_DB_NCHARSET_PARAM ]] && {
    echo "Incorrect parameter provided for ora-db-ncharset: $ORA_DB_NCHARSET"
    exit 1
}
[[ ! "$ORA_DISK_MGMT" =~ $ORA_DISK_MGMT_PARAM ]] && {
    echo "Incorrect parameter provided for ora-disk-mgmt: $ORA_DISK_MGMT"
    exit 1
}
[[ ! "$ORA_ROLE_SEPARATION" =~ $ORA_ROLE_SEPARATION_PARAM ]] && {
    echo "Incorrect parameter provided for ora-role-separation: $ORA_ROLE_SEPARATION"
    exit 1
}
[[ ! "$ORA_DATA_DISKGROUP" =~ $ORA_DATA_DISKGROUP_PARAM ]] && {
    echo "Incorrect parameter provided for ora-data-diskgroup: $ORA_DATA_DISKGROUP"
    exit 1
}
[[ ! "$ORA_RECO_DISKGROUP" =~ $ORA_RECO_DISKGROUP_PARAM ]] && {
    echo "Incorrect parameter provided for ora-reco-diskgroup: $ORA_RECO_DISKGROUP"
    exit 1
}
[[ ! "$ORA_ASM_DISKS" =~ $ORA_ASM_DISKS_PARAM ]] && {
    echo "Incorrect parameter provided for ora-asm-disks: $ORA_ASM_DISKS"
    exit 1
}
[[ ! "$ORA_DATA_MOUNTS" =~ $ORA_DATA_MOUNTS_PARAM ]] && {
    echo "Incorrect parameter provided for ora-data-mounts: $ORA_DATA_MOUNTS"
    exit 1
}
[[ ! "$CLUSTER_CONFIG" =~ $CLUSTER_CONFIG_PARAM ]] && {
    echo "Incorrect parameter provided for cluster-config: $CLUSTER_CONFIG"
    exit 1
}
[[ ! "$ORA_LISTENER_PORT" =~ $ORA_LISTENER_PORT_PARAM ]] && {
    echo "Incorrect parameter provided for ora-listener-port: $ORA_LISTENER_PORT"
    exit 1
}
[[ ! "$ORA_LISTENER_NAME" =~ $ORA_LISTENER_NAME_PARAM ]] && {
    echo "Incorrect parameter provided for ora-listener-name: $ORA_LISTENER_NAME"
    exit 1
}
[[ ! "$ORA_DB_CONTAINER" =~ $ORA_DB_CONTAINER_PARAM ]] && {
    echo "Incorrect parameter provided for ora-db-container: $ORA_DB_CONTAINER"
    exit 1
}
[[ ! "$ORA_DB_TYPE" =~ $ORA_DB_TYPE_PARAM ]] && {
    echo "Incorrect parameter provided for ora-db-type: $ORA_DB_TYPE"
    exit 1
}
[[ ! "$ORA_PDB_NAME_PREFIX" =~ $ORA_PDB_NAME_PREFIX_PARAM ]] && {
    echo "Incorrect parameter provided for ora-pdb-name-prefix: $ORA_PDB_NAME_PREFIX"
    exit 1
}
[[ ! "$ORA_PDB_COUNT" =~ $ORA_PDB_COUNT_PARAM ]] && {
    echo "Incorrect parameter provided for ora-pdb-count: $ORA_PDB_COUNT"
    exit 1
}
[[ ! "$ORA_REDO_LOG_SIZE" =~ $ORA_REDO_LOG_SIZE_PARAM ]] && {
    echo "Incorrect parameter provided for ora-redo-log-size: $ORA_REDO_LOG_SIZE"
    exit 1
}
[[ ! "$BACKUP_DEST" =~ $BACKUP_DEST_PARAM ]] && [[ "$PB_LIST" =~ "config-db.yml" ]] && {
    echo "Incorrect parameter provided for backup-dest: $BACKUP_DEST"
    exit 1
}
[[ ! "$BACKUP_REDUNDANCY" =~ $BACKUP_REDUNDANCY_PARAM ]] && {
    echo "Incorrect parameter provided for backup-redundancy: $BACKUP_REDUNDANCY"
    exit 1
}
[[ ! "$ARCHIVE_REDUNDANCY" =~ $ARCHIVE_REDUNDANCY_PARAM ]] && {
    echo "Incorrect parameter provided for archive-redundancy: $ARCHIVE_REDUNDANCY"
    exit 1
}
[[ ! "$ARCHIVE_ONLINE_DAYS" =~ $ARCHIVE_ONLINE_DAYS_PARAM ]] && {
    echo "Incorrect parameter provided for archive-online-days: $ARCHIVE_ONLINE_DAYS"
    exit 1
}
[[ ! "$BACKUP_LEVEL0_DAYS" =~ $BACKUP_LEVEL0_DAYS_PARAM ]] && {
    echo "Incorrect parameter provided for backup-level0-days: $BACKUP_LEVEL0_DAYS"
    exit 1
}
[[ ! "$BACKUP_LEVEL1_DAYS" =~ $BACKUP_LEVEL1_DAYS_PARAM ]] && {
    echo "Incorrect parameter provided for backup-level1-days: $BACKUP_LEVEL1_DAYS"
    exit 1
}
[[ ! "$BACKUP_START_HOUR" =~ $BACKUP_START_HOUR_PARAM ]] && {
    echo "Incorrect parameter provided for backup-start-hour: $BACKUP_START_HOUR"
    exit 1
}
[[ ! "$BACKUP_START_MIN" =~ $BACKUP_START_MIN_PARAM ]] && {
    echo "Incorrect parameter provided for backup-start-min: $BACKUP_START_MIN"
    exit 1
}
[[ ! "$ARCHIVE_BACKUP_MIN" =~ $ARCHIVE_BACKUP_MIN_PARAM ]] && {
    echo "Incorrect parameter provided for archive-backup-min: $ARCHIVE_BACKUP_MIN"
    exit 1
}
[[ ! "$BACKUP_SCRIPT_LOCATION" =~ $BACKUP_SCRIPT_LOCATION_PARAM ]] && {
    echo "Incorrect parameter provided for backup-start-min: $BACKUP_SCRIPT_LOCATION"
    exit 1
}
[[ ! "$BACKUP_LOG_LOCATION" =~ $BACKUP_LOG_LOCATION_PARAM ]] && {
    echo "Incorrect parameter provided for backup-start-min: $BACKUP_LOG_LOCATION"
    exit 1
}
[[ ! "$INSTANCE_IP_ADDR" =~ ${INSTANCE_IP_ADDR_PARAM} ]] && [[ "$CLUSTER_TYPE" != "RAC" ]] && {
    echo "Incorrect parameter provided for instance-ip-addr: $INSTANCE_IP_ADDR"
    exit 1
}
[[ ! "$PRIMARY_IP_ADDR" =~ ${PRIMARY_IP_ADDR_PARAM} ]] && [[ "$CLUSTER_TYPE" =~ "DG" ]] && {
    echo "Incorrect parameter provided for primary-ip-addr: $PRIMARY_IP_ADDR"
    exit 1
}
[[ ! "$INSTANCE_SSH_USER" =~ $INSTANCE_SSH_USER_PARAM ]] && {
    echo "Incorrect parameter provided for instance-ssh-user: $INSTANCE_SSH_USER"
    exit 1
}
[[ ! "$INSTANCE_SSH_KEY" =~ $INSTANCE_SSH_KEY_PARAM ]] && {
    echo "Incorrect parameter provided for instance-ssh-key: $INSTANCE_SSH_KEY"
    exit 1
}
[[ ! "$NTP_PREF" =~ $NTP_PREF_PARAM ]] && {
    echo "Incorrect parameter provided for ntp-pref: $NTP_PREF"
    exit 1
}
[[ ! "$SWAP_BLK_DEVICE" =~ $SWAP_BLK_DEVICE_PARAM ]] && {
    echo "Incorrect parameter provided for swap-blk-device: $SWAP_BLK_DEVICE"
    exit 1
}
[[ ! "$COMPATIBLE_RDBMS" =~ $COMPATIBLE_RDBMS_PARAM ]] && {
    echo "Incorrect parameter provided for compatible-rdbms: $COMPATIBLE_RDBMS"
    exit 1
}

if [[ "${skip_compatible_rdbms}" != "true" ]]; then
  #
  # compatible-rdbms cannot be > ORA-VERSION
  #
     NON_DOTTED_VER=$(echo $ORA_VERSION | sed s'/\.//g')
  NON_DOTTED_COMPAT=$(echo $COMPATIBLE_RDBMS | sed s'/\.//g' | sed s'/0*$//')
     NON_DOTTED_VER=$(echo ${NON_DOTTED_VER:0:${#NON_DOTTED_COMPAT}})

  if (( NON_DOTTED_COMPAT > NON_DOTTED_VER ))
  then
    printf "\n\033[1;36m%s\033[m\n\n" "compatible-rdbms cannot be higher than the database version being installed."
    exit 345
  fi
fi

# Mandatory options
if [ "${ORA_SWLIB_BUCKET}" = "" ]; then
  echo "Please specify a GS bucket with --ora-swlib-bucket"
  exit 2
fi

# if the hostgroup is not the default then error out when there is no corresponding group_vars/var.yml file
if [ "${INSTANCE_HOSTGROUP_NAME}" != "dbasm" -a ! -r group_vars/${INSTANCE_HOSTGROUP_NAME}.yml ]; then
  echo "Custom ansible hostgroup defined as ${INSTANCE_HOSTGROUP_NAME} but no corresponding group_vars/${INSTANCE_HOSTGROUP_NAME}.yml file found"
  exit 2
fi

#
# Build the inventory file if no inventory file specified on the command line
#
if [[ -z ${INVENTORY_FILE_PARAM} ]]; then
COMMON_OPTIONS="ansible_ssh_user=${INSTANCE_SSH_USER} ansible_ssh_private_key_file=${INSTANCE_SSH_KEY} ansible_ssh_extra_args=${INSTANCE_SSH_EXTRA_ARGS}"
  #
  # If $CLUSTER_TYPE = RAC then we use $CLUSTER_CONFIG to build the inventory file
  #
  if [[ "${CLUSTER_TYPE}" = "RAC" ]]; then
    # We will be using jq to process the JSON configuration so we check if jq is installed on the system first
    command -v jq >/dev/null 2>&1 || { echo >&2 "jq is needed for the RAC feature but has not been detected in this sytem. Cannot continue."; exit 678;}

    # Verify that the JSON configuration file exists
    if [[ ! -f "${CLUSTER_CONFIG}" ]]; then
      printf "\n\033[1;31m%s\033[m\n\n" "Cluser type is set to ${CLUSTER_TYPE} but we cannot find the configuration file ${CLUSTER_CONFIG}; cannot continue."
      exit 456
    fi

    # Name of the inventory file
    INVENTORY_FILE="${INVENTORY_FILE}_${ORA_DB_NAME}_${CLUSTER_TYPE}"

    # We can now fill the inventory file with the information from the JSON file
    echo "[${INSTANCE_HOSTGROUP_NAME}]" > "${INVENTORY_FILE}"

    # jq filters for better visibility
    OLDIFS="${IFS}"
    IFS='' read -r -d '' JQF << EOF
    .[] | .nodes[] | .node_name + " ansible_ssh_host=" + .host_ip
    + " vip_name=" + .vip_name + " vip_ip=" + .vip_ip
EOF
    IFS="${OLDIFS}"
    jq -rc "${JQF}" "${CLUSTER_CONFIG}" | awk -v COMMON_OPTIONS="${COMMON_OPTIONS}" '{print $0" " COMMON_OPTIONS}' >> "${INVENTORY_FILE}"

    printf "\n" >> "${INVENTORY_FILE}"

    echo "[${INSTANCE_HOSTGROUP_NAME}:vars]" >> "${INVENTORY_FILE}"

    # jq filters for better visibility
    OLDIFS="${IFS}"
    IFS='' read -r -d '' JQF << EOF
    .[] |
    with_entries(.value = if .value|type != "array" then .value else empty end) |
    with_entries(select(.value != "")) |
    to_entries[] | .key + "=" + .value
EOF
    IFS="${OLDIFS}"
    jq -rc "${JQF}" "${CLUSTER_CONFIG}" >> "${INVENTORY_FILE}"

  elif [[ ! -z ${PRIMARY_IP_ADDR} ]]; then
    INVENTORY_FILE="${INVENTORY_FILE}_${INSTANCE_HOSTNAME}_${ORA_DB_NAME}"
    cat <<EOF > ${INVENTORY_FILE}
[${INSTANCE_HOSTGROUP_NAME}]
${INSTANCE_HOSTNAME} ansible_ssh_host=${INSTANCE_IP_ADDR} ${COMMON_OPTIONS}

[primary]
primary1 ansible_ssh_host=${PRIMARY_IP_ADDR} ${COMMON_OPTIONS}
EOF
  else   # Non RAC
    INVENTORY_FILE="${INVENTORY_FILE}_${INSTANCE_HOSTNAME}_${ORA_DB_NAME}"
    cat <<EOF > ${INVENTORY_FILE}
[${INSTANCE_HOSTGROUP_NAME}]
${INSTANCE_HOSTNAME} ansible_ssh_host=${INSTANCE_IP_ADDR} ${COMMON_OPTIONS}
EOF
  fi     # End of if RAC
else
  INVENTORY_FILE="${INVENTORY_FILE_PARAM}"
fi
if [[ -f "${INVENTORY_FILE}" ]]; then
  printf "\n\033[1;36m%s\033[m\n\n" "Inventory file for this execution: ${INVENTORY_FILE}."
else
  printf "\n\033[1;31m%s\033[m\n\n" "Cannot find the inventory file ${INVENTORY_FILE}; cannot continue."
  exit 124
fi
#
# Build the logfile for this session
#
if [[ "${CLUSTER_TYPE}" = "RAC" ]] || [[ "${CLUSTER_TYPE}" = "DG" ]]; then
  LOG_FILE="${LOG_FILE}_${ORA_DB_NAME}_${TIMESTAMP}_${CLUSTER_TYPE}.log"
else
  LOG_FILE="${LOG_FILE}_${INSTANCE_HOSTNAME}_${ORA_DB_NAME}_${TIMESTAMP}.log"
fi
export ANSIBLE_LOG_PATH=${LOG_FILE}

#
# if RAC then use config-rac-db playboook, otherwise - config-db
#
if [[ "${CLUSTER_TYPE}" = "RAC" ]]; then
  PB_LIST=${PB_LIST/$PB_CONFIG_DB/config-rac-db.yml}
  PB_CONFIG_DB="config-rac-db.yml"
fi

#
# Trim tailing slashes from variables with paths
#
BACKUP_DEST=${BACKUP_DEST%/}
BACKUP_LOG_LOCATION=${BACKUP_LOG_LOCATION%/}
BACKUP_SCRIPT_LOCATION=${BACKUP_SCRIPT_LOCATION%/}
ORA_STAGING=${ORA_STAGING%/}
ORA_SWLIB_BUCKET=${ORA_SWLIB_BUCKET%/}
ORA_SWLIB_PATH=${ORA_SWLIB_PATH%/}

export ARCHIVE_BACKUP_MIN
export ARCHIVE_ONLINE_DAYS
export ARCHIVE_REDUNDANCY
export BACKUP_DEST
export BACKUP_LEVEL0_DAYS
export BACKUP_LEVEL1_DAYS
export BACKUP_LOG_LOCATION
export BACKUP_REDUNDANCY
export BACKUP_START_HOUR
export BACKUP_START_MIN
export CLUSTER_TYPE
export CLUSTER_CONFIG
export COMPATIBLE_RDBMS
export INSTANCE_IP_ADDR
export NTP_PREF
export ORA_DATA_DISKGROUP
export ORA_DB_CHARSET
export ORA_DB_CONTAINER
export ORA_DB_DOMAIN
export ORA_DB_NAME
export ORA_DB_NCHARSET
export ORA_DB_TYPE
export ORA_DISK_MGMT
export ORA_EDITION
export ORA_LISTENER_NAME
export ORA_LISTENER_PORT
export ORA_PDB_COUNT
export ORA_PDB_NAME_PREFIX
export ORA_RECO_DISKGROUP
export ORA_ASM_DISKS
export ORA_DATA_MOUNTS
export ORA_REDO_LOG_SIZE
export ORA_ROLE_SEPARATION
export ORA_STAGING
export ORA_SWLIB_BUCKET
export ORA_SWLIB_CREDENTIALS
export ORA_SWLIB_TYPE
export ORA_SWLIB_PATH
export ORA_VERSION
export ORA_RELEASE
export PB_LIST
export PRIMARY_IP_ADDR

echo -e "Running with parameters from command line or environment variables:\n"
set | egrep '^(ORA_|BACKUP_|ARCHIVE_|INSTANCE_|PB_|ANSIBLE_|CLUSTER|PRIMARY)' | grep -v '_PARAM='
echo

ANSIBLE_PARAMS="-i ${INVENTORY_FILE} ${ANSIBLE_PARAMS}"
ANSIBLE_EXTRA_PARAMS="${*}"

echo "Ansible params: ${ANSIBLE_EXTRA_PARAMS}"

if [ $VALIDATE -eq 1 ]; then
  echo "Exiting because of --validate"
  exit;
fi

export ANSIBLE_NOCOWS=1

ANSIBLE_PLAYBOOK="ansible-playbook"
if ! type ansible-playbook > /dev/null 2>&1; then
  echo "Ansible executable not found in path"
  exit 3
else
  echo "Found Ansible: `type ansible-playbook`"
fi

# exit on any error from the following scripts
set -e

for PLAYBOOK in ${PB_LIST}; do
  ANSIBLE_COMMAND="${ANSIBLE_PLAYBOOK} ${ANSIBLE_PARAMS} ${ANSIBLE_EXTRA_PARAMS} ${PLAYBOOK}"
  echo
  echo "Running Ansible playbook: ${ANSIBLE_COMMAND}"
  eval ${ANSIBLE_COMMAND}
done
#
# Show the files used by this session
#
printf "\n\033[1;36m%s\033[m\n" "Files used by this session:"
for FILE in "${INVENTORY_FILE}" "${LOG_FILE}"; do
  if [[ -f "${FILE}" ]]; then
    printf "\t\033[1;36m- %s\033[m\n" "${FILE}"
  fi
done
printf "\n"

exit 0
