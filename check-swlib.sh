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


# need awk

# Script returns:
# 0 - successfully checked the bucket for specified version
# 1 - files are missing from the bucket
# 2 - files are present but size or md5sum does not match

[[ -x /usr/bin/awk ]] || {
    echo "Please install awk under /usr/bin/awk for the script to run"
    exit 99
}

GETOPT_MANDATORY="ora-swlib-bucket:"
GETOPT_OPTIONAL="ora-version:,help"
GETOPT_LONG="${GETOPT_MANDATORY},${GETOPT_OPTIONAL}"
GETOPT_SHORT="h"

ORACLE_SWLIB="oracle-swlib.csv"

ORA_VERSION="${ORA_VERSION:-19.3.0.0.0}"
ORA_VERSION_PARAM='^(19\.3\.0\.0\.0|18\.0\.0\.0\.0|12\.2\.0\.1\.0|12\.1\.0\.2\.0|11\.2\.0\.4\.0|ALL)$'

ORA_SWLIB_BUCKET="${ORA_SWLIB_BUCKET}"
ORA_SWLIB_BUCKET_PARAM='^gs://.+$'

EXITCODE=0

options=$(getopt --longoptions "$GETOPT_LONG" --options "$GETOPT_SHORT" -- "$@")

[ $? -eq 0 ] || {
       echo "Invalid options provided: $*"
       exit 1
}

eval set -- "$options"

while true; do
    case "$1" in
    --ora-swlib-bucket)
        ORA_SWLIB_BUCKET="`echo $2|sed 's/\/\+$//'`"
        shift;
        ;;
    --ora-version)
        ORA_VERSION="$2"
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

[[ ! "$ORA_VERSION" =~ $ORA_VERSION_PARAM ]] && {
    echo "Incorrect parameter provided for ora-version: $ORA_VERSION"
    exit 1
}
[[ ! "$ORA_SWLIB_BUCKET" =~ $ORA_SWLIB_BUCKET_PARAM ]] && {
    echo "Incorrect parameter provided for ora-swlib-bucket: $ORA_SWLIB_BUCKET"
    exit 1
}

# Mandatory options
if [ "${ORA_SWLIB_BUCKET}" = "" ]; then
    echo "Please specify a GS bucket with --ora-swlib-bucket"
    exit 2
fi

echo -e "Running with parameters from command line or environment variables:\n"
set | egrep '^(ORA_|BACKUP_|ARCHIVE_)' | grep -v '_PARAM='
echo

# Load swlib data
[[ ! -f ${ORACLE_SWLIB} ]] && {
    echo "File not found: ${ORACLE_SWLIB}, cannot continue"; exit 99;
}

OLDIFS=$IFS

IFS=,
while read filename version desc size md5sum sha256sum
do
    if [[ ${ORA_VERSION} == ${version} || ${ORA_VERSION} == "ALL" ]]; then
        GSUTIL_OUT=`gsutil ls -L ${ORA_SWLIB_BUCKET}/${filename} 2>&1`
        GSUTIL_RES=$?
        if [[ ${GSUTIL_RES} -eq 0 ]]; then
            echo "Found $filename : $desc"
            #echo $GSUTIL_OUT
            GSUTIL_FILE_SIZE=`echo $GSUTIL_OUT | awk '/Content-Length:/{print $2}'`
            GSUTIL_FILE_MD5=`echo $GSUTIL_OUT | awk '/Hash..md5.:/{print $3}'| base64 -d | od -t x1 -A n | tr -d ' '`
            #echo $GSUTIL_FILE_SIZE, $GSUTIL_FILE_MD5
            #echo $size, $md5sum
            if [[ "$GSUTIL_FILE_SIZE" != "$size" ]]; then
                echo -en "\tsize does not match (remote: $GSUTIL_FILE_SIZE, expected: $size), "
                EXITCODE=2
            else
                echo -en "\tfile size matches ($size), "
            fi
            if [[ "$GSUTIL_FILE_MD5" != "$md5sum" ]]; then
                echo "md5 does not match (remote: $GSUTIL_FILE_MD5, expected: $md5sum)."
                EXITCODE=2
            else
                echo "md5 matches ($md5sum)."
            fi

        else
            echo "Object ${ORA_SWLIB_BUCKET}/${filename} $desc not found: ${GSUTIL_OUT}"
            EXITCODE=1
        fi
        echo
    fi
done < ${ORACLE_SWLIB}

IFS=$OLDIFS

exit $EXITCODE
