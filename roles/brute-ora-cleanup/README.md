# Oracle Brute Force Clean-up

*Caution - destructive tasks - will permanentally erase software*

Role to do a brute force removal of all Oracle software on server.  Run with Oracle/GI services up.

Sample execution:

```bash
ansible-playbook brute-cleanup.yml --extra-vars "oracle_ver=11.2.0.4.0"
```


## Items not covered ##

* Removal of ASMlib packages (if installed)
* Removal of udev rules (if configured)
