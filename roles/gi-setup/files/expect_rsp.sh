#!/bin/bash

# Create OCM response file using expect
# Accepts two passed parameters:
#
#    $1: ORACLE_BASE
#    $2: ORACLE_HOME
#    $3: Destination for the response file
#

export ORACLE_BASE=${1}
export ORACLE_HOME=${2}
export RSP_PATH=${3}

if [ -f "${ORACLE_HOME}/OPatch/ocm/bin/emocmrsp" ]; then
   cat <<EOF > ${RSP_PATH}/ocm.sh
#!/usr/bin/expect -f
set timeout -1
spawn ${ORACLE_HOME}/OPatch/ocm/bin/emocmrsp -no_banner -output ${RSP_PATH}/ocm.rsp
expect "Email address/User Name:"
send "\n"
expect "Do you wish to remain uninformed of security issues*"
send "Y\n"
expect eof
EOF
   chmod 700 ${RSP_PATH}/ocm.sh
   ${RSP_PATH}/ocm.sh
   rm ${RSP_PATH}/ocm.sh
fi
