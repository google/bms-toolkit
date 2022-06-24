# bms-toolkit tools

The `tools/` folder is intended for helpful tools and scripts that aren't
part of the main bms-toolkit codebase.

## gen_patch_metadata

`gen_patch_metadata` retrieves patches from My Oracle Support, parses our
version and hash information, and prepares `rdbms_patches` and `gi_patches`
structures for `roles/common/defaults/main.yml`.

### Sample usage

```
$ python3 gen_patch_metadata.py --patch 33567274 --mosuser user@example.com
MOS Password:
INFO:root:Downloading https://updates.oracle.com/Orion/Download/process_form/p33567274_190000_Linux-x86-64.zip?file_id=113789887&aru=24594397&userid=O-user@example.com&email=user@example.com&patch_password=&patch_file=p33567274_190000_Linux-x86-64.zip
INFO:root:Abstract: COMBO OF OJVM RU COMPONENT 19.14.0.0.220118 + GI RU 19.14.0.0.220118
INFO:root:Found release = 19.0.0.0.0 base = 19.14.0.0.220118 GI subdir = 33509923 OJVM subdir = 33561310
INFO:root:Downloading OPatch
INFO:root:Downloading https://updates.oracle.com/Orion/Download/process_form/p6880880_190000_Linux-x86-64.zip?aru=24740828&file_id=112014090&patch_file=p6880880_190000_Linux-x86-64.zip&
Please copy the following files to your GCS bucket: p33567274_190000_Linux-x86-64.zip p6880880_190000_Linux-x86-64.zip
Add the following to the appropriate sections of roles/common/defaults/main.yml:

  gi_patches:
    - { category: "RU", base: "19.14.0.0.220118", release: "19.0.0.0.0", patchnum: "33567274", patchfile: "p33567274_190000_Linux-x86-64.zip", patch_subdir: "/33509923", prereq_check: FALSE, method: "opatchauto apply", ocm: FALSE, upgrade: FALSE, md5sum: "JgJsqbGaGcxEPEP6j79BPQ==" }

  rdbms_patches:
    - { category: "RU_Combo", base: "19.14.0.0.220118", release:
        "19.0.0.0.0", patchnum: "33567274, patchfile: "p33567274_190000_Linux-x86-64.zip", patch_subdir: "/33561310", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "JgJsqbGaGcxEPEP6j79BPQ==" }
```

### Known issues

* Only tested against 12.2, 18c, and 19c patches.
* No support for multi-file patches.
