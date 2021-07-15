#### A note on patch metadata

The patching code derives the patch metadata from the following blocks in the file role/common/default/main.yml:

```
gi_patches:
...
- { category: "RU", base: "19.3.0.0.0", release: "19.9.0.0.201020", patchnum: "31720429", patchfile: "p31720429_190000_Linux-x86-64.zip", patch_subdir: "/31750108", prereq_check: FALSE, method: "opatchauto apply", ocm: FALSE, upgrade: FALSE }


rdbms_patches:
...
- { category: "RU_Combo", base: "19.3.0.0.0", release: "19.9.0.0.201020", patchnum: "31720429", patchfile: "p31720429_190000_Linux-x86-64.zip", patch_subdir: "/31668882", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE }
```

These metadata numbers can be taken from consulting appropriate MOS Notes, such as:
* Master Note for Database Proactive Patch Program (Doc ID 888.1)
* Oracle Database 19c Proactive Patch Information (Doc ID 2521164.1)
* Database 18c Proactive Patch Information (Doc ID 2369376.1)
* Database 12.2.0.1 Proactive Patch Information (Doc ID 2285557.1)

Bearing in mind that the GI RU's patch zipfile contains the patch molecules that go both into the GI_HOME as well as the RDBMS_HOME, the Combo patch of OJVM+GI is self-contained as to the necessary patches needed to patch a given host for a given quarter. For example: the patch zipfile `p31720429_190000_Linux-x86-64.zip` contains the following patch directories:
```
├── 31720429
│   ├── 31668882  <================ this is the OJVM RU for that quarter
│   │   ├── etc
│   │   ├── files
│   │   ├── README.html
│   │   └── README.txt
│   ├── 31750108  <================ this is GI RU for the given quarter
│   │   ├── 31771877
│   │   ├── 31772784
│   │   ├── 31773437
│   │   ├── 31780966
│   │   ├── automation
│   │   ├── bundle.xml
│   │   ├── README.html
│   │   └── README.txt
│   ├── PatchSearch.xml
│   └── README.html
└── PatchSearch.xml

```
Accordingly the patch_subdir values can be edited, as noted in the foregoing.
