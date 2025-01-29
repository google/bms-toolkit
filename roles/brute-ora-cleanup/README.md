# Oracle Brute Force Clean-up

_Caution - destructive tasks - will permanently erase software_

Role to do a brute force removal of all Oracle software on server. Run with Oracle/GI services up.

Objective is to return the target server to the pre-Oracle software installation state. Consequently all files, directories, and databases are permanently removed.

Sample execution:

```bash
ansible-playbook brute-cleanup.yml --extra-vars "oracle_ver=11.2.0.4.0"
```

## Free Edition Clean-up

Oracle Database Free Edition is exclusively an RPM installation and supports numerous [versions](../../docs/user-guide.md#free-edition-version-details) without patches.

Therefore, to run a brute force removal of an Oracle Database Free Edition installation, specify the appropriate version with the `--ora-version` command line argument, and also include `--ora-edition FREE` to differentiate from a commercial edition installation of the same version.

A brute force cleanup of a Free Edition database will attempt to first remove the existing database/listener and uninstall the software cleanly. Should that process fail or be unable to run due to a broken installation, forceful removal steps will be taken to ensure that the target server is left in an clean state.

Sample brute force clean-up for Free Edition using the included shell script:

```bash
./cleanup-oracle.sh \
  --ora-edition FREE \
  --ora-version 23.6.0.24.10 \
  --inventory-file inventory_files/inventory_10.2.80.54_FREE \
  --yes-i-am-sure
```
