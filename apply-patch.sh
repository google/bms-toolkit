#!/bin/bash

# Check if we're using the Mac stock getopt and fail if true
out=`getopt -T`
if [ $? != 4 ]; then
    echo -e "Your getopt does not support long parametrs, possibly you're on a Mac, if so please install gnu-getopt with brew"
    echo -e "\thttps://brewformulas.org/Gnu-getopt"
    exit
fi

ORA_VERSION="${ORA_VERSION:-18.0.0.0.0}"
ORA_VERSION_PARAM='^(19\.3\.0\.0\.0|18\.0\.0\.0\.0|12\.2\.0\.1\.0|12\.1\.0\.2\.0|11\.2\.0\.4\.0)$'

ORA_SWLIB_BUCKET="${ORA_SWLIB_BUCKET}"
ORA_SWLIB_BUCKET_PARAM="^gs://.+"

ORA_STAGING="${ORA_STAGING:-/u02/oracle_install}"
ORA_STAGING_PARAM="^/.+$"

ORA_DB_NAME="${ORA_DB_NAME:-ORCL}"
ORA_DB_NAME_PARAM="^[a-zA-Z0-9_$]+$"

###
GETOPT_MANDATORY="ora-swlib-bucket:"
GETOPT_OPTIONAL="ora-version:,ora-staging:,ora-db-name:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,help,validate"
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
        shift;
        ;;
    --ora-swlib-bucket)
        ORA_SWLIB_BUCKET="$2"
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

shopt -s nocasematch

[[ ! "$ORA_VERSION" =~ $ORA_VERSION_PARAM ]] && {
    echo "Incorrect parameter provided for ora-version: $ORA_VERSION"
    exit 1
}
[[ ! "$ORA_SWLIB_BUCKET" =~ $ORA_SWLIB_BUCKET_PARAM ]] && {
    echo "Incorrect parameter provided for ora-swlib-bucket: $ORA_SWLIB_BUCKET"
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

# Mandatory options
if [ "${ORA_SWLIB_BUCKET}" = "" ]; then
    echo "Please specify a GS bucket with --ora-swlib-bucket"
    exit 2
fi

export ORA_DB_NAME
export ORA_STAGING
export ORA_SWLIB_BUCKET
export ORA_VERSION

echo -e "Running with parameters from command line or environment variables:\n"
set | egrep '^(ORA_|BACKUP_|ARCHIVE_)' | grep -v '_PARAM='
echo

ANSIBLE_PARAMS="$*"

echo "Ansible params: ${ANSIBLE_PARAMS}"

if [ $VALIDATE -eq 1 ]; then
    echo "Exiting because of --validate"
    exit;
fi

export ANSIBLE_NOCOWS=1

ANSIBLE_PLAYBOOK=`which ansible-playbook 2> /dev/null`
if [ $? -ne 0 ]; then
    echo "Ansible executable not found in path"
    exit 3
else
    echo "Found Ansible at $ANSIBLE_PLAYBOOK"
fi


# exit on any error from the following scripts
set -e

echo "Running Ansible playbook: ${ANSIBLE_PLAYBOOK} ${ANSIBLE_PARAMS} patch.yml"
${ANSIBLE_PLAYBOOK} ${ANSIBLE_PARAMS} patch.yml

exit 0;
