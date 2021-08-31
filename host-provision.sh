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

shopt -s nocasematch

# Check if we're using the Mac stock getopt and fail if true
out=`getopt -T`
if [ $? != 4 ]; then
  echo -e "Your getopt does not support long parameters, possibly you're on a Mac, if so please install gnu-getopt with brew"
  echo -e "\thttps://brewformulas.org/Gnu-getopt"
  exit
fi

# set -x
GETOPT_MANDATORY="inventory-file:"
# GETOPT_OPTIONAL="ora-role-separation:,ora-disk-mgmt:,ora-swlib-path:,ora-staging:,ora-asm-disks:,ora-data-mounts:,help"
GETOPT_OPTIONAL="hostprovision-ansible-user:,help"
GETOPT_LONG="${GETOPT_MANDATORY},${GETOPT_OPTIONAL}"
GETOPT_SHORT="h"


INVENTORY_FILE="${INVENTORY_FILE:-./inventory_files/inventory}"


options=$(getopt --longoptions "$GETOPT_LONG" --options "$GETOPT_SHORT" -- "$@")

[ $? -eq 0 ] || {
       echo "Invalid options provided: $*"
       exit 1
}

# echo "PARSED COMMAND LINE FLAGS: $options"

eval set -- "$options"

while true; do
    case "$1" in
    --inventory-file)
        INVENTORY_FILE="$2"
        shift;
        ;;
    --hostprovision-ansible-user)
        ORA_HOSTPROVISION_ANSIBLE_USER="$2"
        shift;
        ;;
    --help|-h)
        echo -e "\tUsage: `basename $0` "
        echo $GETOPT_MANDATORY|sed 's/,/\n/g'|sed 's/:/ <value>/'|sed 's/\(.\+\)/\t  --\1/'
        echo $GETOPT_OPTIONAL |sed 's/,/\n/g'|sed 's/:/ <value>/'|sed 's/\(.\+\)/\t  [ --\1 ]/'
        exit 2
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done


if [[ ! -s ${INVENTORY_FILE} ]]; then
    echo "Please specify the inventory file using --inventory-file <file_name>"
    exit 2
fi


export ORA_HOSTPROVISION_ANSIBLE_USER

echo -e "Running with parameters from command line or environment variables:\n"
set | egrep '^(ORA_|INVENTORY_)' | grep -v '_PARAM='
echo

ANSIBLE_PARAMS="-i ${INVENTORY_FILE} ${ANSIBLE_PARAMS}"
ANSIBLE_EXTRA_PARAMS="${*}"

export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

ANSIBLE_PLAYBOOK=`which ansible-playbook 2> /dev/null`
if [ $? -ne 0 ]; then
  echo "Ansible executable not found in path"
  exit 3
else
  echo "Found Ansible at $ANSIBLE_PLAYBOOK"
fi

# exit on any error from the following scripts
set -e

PLAYBOOK="host-provision.yml"
ANSIBLE_COMMAND="${ANSIBLE_PLAYBOOK} ${ANSIBLE_PARAMS} ${ANSIBLE_EXTRA_PARAMS} ${PLAYBOOK}"
echo
echo "Running Ansible playbook: ${ANSIBLE_COMMAND}"
eval ${ANSIBLE_COMMAND}
