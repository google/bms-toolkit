### Objective:
The `install-ahf.sh` utility is used to roll out Oracle Autonomous Framework [(AHF)](https://docs.oracle.com/en/engineered-systems/health-diagnostics/autonomous-health-framework/).
The intent of this doc is to concisely list the input parameters to the `install-ahf.sh` utility, usage and a sample run.


### Input parameters:

Parameter          | Optional / Mandatory| Description                                           | Example                         
----------------|------------------------|-------------------------------------------------------|--------------------------------------
--ahf-patchfile  | Mandatory              | The name of the AHF installer zipfile that is stored in GCS       | --ahf-patchfile AHF-LINUX_v21.4.0.new.zip 
--ora-swlib-bucket | Mandatory            | The name of the GCS bucket where the AHF installer zipfile is stored|--ora-swlib-bucket gs://oracle-software
--ora-swlib-path  | Optional (Defaults to `/u01/oracle_install`) | Path on the BMX DB host where the AHF installer file will be copied into from GCS|--ora-swlib-path /u01/staging
--inventory-file | Mandatory     | The Ansible inventory file containing the BMX host name/IP/proxy settings | --inventory-file inventory_files/inventory_orcl_nonrac_primary_syd1 

A sample inventory file content could be:
```
✔ ~/mydrive/bmaas/PSU_testing/log4j/bms-toolkit [master|✚ 1] 
14:40 $ cat inventory_files/inventory_bmx_db_host
[dbasm]
at-00-smehost ansible_ssh_host=192.10.110.1 ansible_ssh_user=ansible9 ansible_ssh_private_key_file=/usr/.ssh/id_rsa_bms_toolkit ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentityAgent=no -o IdentitiesOnly=true -o ProxyCommand="ssh -W %h:%p -q user@jumphost.company.com"'
```

### Usage:
```
./install-ahf.sh --ahf-patchfile AHF-LINUX_v21.4.0.new.zip --ora-swlib-bucket gs://oracle-software --ora-swlib-path /u01/oracle_install --inventory-file inventory_files/inventory_bmx_db_host 
```

### Sample run:
```
✔ ~/mydrive/bms-toolkit [log4j L|✚ 11…11] 
13:03 $ ./install-ahf.sh --ahf-patchfile AHF-LINUX_v21.4.0.new.zip --ora-swlib-bucket gs://oracle-software --ora-swlib-path /u01/oracle_install --inventory-file inventory_files/inventory_bmx_db_host 
Command used:
/usr/local/google/home/jcnarasimhan/mydrive/bmaas/PSU_testing/log4j/bms-toolkit/install-ahf.sh --ahf-patchfile AHF-LINUX_v21.4.0.new.zip --ora-swlib-bucket gs://bmaas-testing-oracle-software --ora-swlib-path /u01/oracle_install --inventory-file inventory_files/inventory_bmx_db_host

Running with parameters from command line or environment variables:

ORA_AHF_PATCHFILE=AHF-LINUX_v21.4.0.new.zip
ORA_STAGING=
ORA_SWLIB_BUCKET=gs://oracle-software
ORA_SWLIB_PATH=/u01/oracle_install

Ansible params: -i inventory_files/inventory_bmx_db_host  
Found Ansible: ansible-playbook is /usr/bin/ansible-playbook
Running Ansible playbook: ansible-playbook -i inventory_files/inventory_bmx_db_host   ahf_patch.yml

PLAY [Download AHF patchfile from GCS bucket] **********************************************************************************************************************************

TASK [Copy AHF patchfile from GCS to target instance] **************************************************************************************************************************
changed: [at-00-smehost.orcl]

PLAY [Install AHF] *************************************************************************************************************************************************************

TASK [Create staging temp directory] *******************************************************************************************************************************************
changed: [at-00-smehost.orcl]

TASK [Remove DATA_DIR if it exists] ********************************************************************************************************************************************
ok: [at-00-smehost.orcl]

TASK [Create DATA_DIR] *********************************************************************************************************************************************************
changed: [at-00-smehost.orcl]

TASK [Copy AHF installer from software library to tempdir for extraction] ******************************************************************************************************
changed: [at-00-smehost.orcl]

TASK [Run installer] ***********************************************************************************************************************************************************
changed: [at-00-smehost.orcl]

TASK [Show installer output] ***************************************************************************************************************************************************
ok: [at-00-smehost.orcl] => {
    "installer": {
        "changed": true,
        "cmd": [
            "/tmp/ansible.YauJKaahf/ahf_setup",
            "-local",
            "-silent",
            "-data_dir",
            "/u01/oracle.ahf/data"
        ],
        "delta": "0:00:37.136433",
        "end": "2021-12-29 13:05:31.897146",
        "failed": false,
        "rc": 0,
        "start": "2021-12-29 13:04:54.760713",
        "stderr": "",
        "stderr_lines": [],
        "stdout": "\nAHF Installer for Platform Linux Architecture x86_64\n\nAHF Installation Log : /tmp/ahf_install_214000_31438_2021_12_29-13_04_54.log\n\nStarting Autonomous Health Framework (AHF) Installation\n\nAHF Version: 21.4.0 Build Date: 202112200745\n\nAHF Location : /opt/oracle.ahf\n\nAHF Data Directory : /u01/oracle.ahf/data\n\nExtracting AHF to /opt/oracle.ahf\n\nConfiguring TFA Services\n\nDiscovering Nodes and Oracle Resources\n\nNot generating certificates as GI discovered\n\nStarting TFA Services\n\n.--------------------------------------------------------------------------------.\n| Host          | Status of TFA | PID | Port | Version    | Build ID             |\n+---------------+---------------+-----+------+------------+----------------------+\n| at-00-smehost | RUNNING       | 450 | 5000 | 21.4.0.0.0 | 21400020211220074549 |\n'---------------+---------------+-----+------+------------+----------------------'\n\nRunning TFA Inventory...\n\nAdding default users to TFA Access list...\n\n.-----------------------------------------------------------.\n|                Summary of AHF Configuration               |\n+-----------------+-----------------------------------------+\n| Parameter       | Value                                   |\n+-----------------+-----------------------------------------+\n| AHF Location    | /opt/oracle.ahf                         |\n| TFA Location    | /opt/oracle.ahf/tfa                     |\n| Orachk Location | /opt/oracle.ahf/orachk                  |\n| Data Directory  | /u01/oracle.ahf/data                    |\n| Repository      | /u01/oracle.ahf/data/repository         |\n| Diag Directory  | /u01/oracle.ahf/data/at-00-smehost/diag |\n'-----------------+-----------------------------------------'\n\n\nStarting orachk scheduler from AHF ...\n\nAHF binaries are available in /opt/oracle.ahf/bin\n\nAHF is successfully installed\n\nMoving /tmp/ahf_install_214000_31438_2021_12_29-13_04_54.log to /u01/oracle.ahf/data/at-00-smehost/diag/ahf/",
        "stdout_lines": [
            "",
            "AHF Installer for Platform Linux Architecture x86_64",
            "",
            "AHF Installation Log : /tmp/ahf_install_214000_31438_2021_12_29-13_04_54.log",
            "",
            "Starting Autonomous Health Framework (AHF) Installation",
            "",
            "AHF Version: 21.4.0 Build Date: 202112200745",
            "",
            "AHF Location : /opt/oracle.ahf",
            "",
            "AHF Data Directory : /u01/oracle.ahf/data",
            "",
            "Extracting AHF to /opt/oracle.ahf",
            "",
            "Configuring TFA Services",
            "",
            "Discovering Nodes and Oracle Resources",
            "",
            "Not generating certificates as GI discovered",
            "",
            "Starting TFA Services",
            "",
            ".--------------------------------------------------------------------------------.",
            "| Host          | Status of TFA | PID | Port | Version    | Build ID             |",
            "+---------------+---------------+-----+------+------------+----------------------+",
            "| at-00-smehost | RUNNING       | 450 | 5000 | 21.4.0.0.0 | 21400020211220074549 |",
            "'---------------+---------------+-----+------+------------+----------------------'",
            "",
            "Running TFA Inventory...",
            "",
            "Adding default users to TFA Access list...",
            "",
            ".-----------------------------------------------------------.",
            "|                Summary of AHF Configuration               |",
            "+-----------------+-----------------------------------------+",
            "| Parameter       | Value                                   |",
            "+-----------------+-----------------------------------------+",
            "| AHF Location    | /opt/oracle.ahf                         |",
            "| TFA Location    | /opt/oracle.ahf/tfa                     |",
            "| Orachk Location | /opt/oracle.ahf/orachk                  |",
            "| Data Directory  | /u01/oracle.ahf/data                    |",
            "| Repository      | /u01/oracle.ahf/data/repository         |",
            "| Diag Directory  | /u01/oracle.ahf/data/at-00-smehost/diag |",
            "'-----------------+-----------------------------------------'",
            "",
            "",
            "Starting orachk scheduler from AHF ...",
            "",
            "AHF binaries are available in /opt/oracle.ahf/bin",
            "",
            "AHF is successfully installed",
            "",
            "Moving /tmp/ahf_install_214000_31438_2021_12_29-13_04_54.log to /u01/oracle.ahf/data/at-00-smehost/diag/ahf/"
        ]
    }
}

TASK [Clean up staging directory] **********************************************************************************************************************************************
ok: [at-00-smehost.orcl]

PLAY RECAP *********************************************************************************************************************************************************************
at-00-smehost.orcl         : ok=8    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

```