# Role Name

Ansible Role: hugepages

Enable Huge Pages on Linux for oracle purposes

For calculation of the hugepages usually the math goes like this:

```
X = grep Hugepagesize /proc/meminfo => (the default value is 2048KB = 2MB)
Y = all client SGAs in MB => (we usually take 70% of the overall RAM since sometimes we can not plan ahead how much SGA would be required for the database but in any case we usually don't go higher then 70% of the overall RAM )
Z = #Huge Pages needed = Y / X

Also since database SGA size is tightly related with SHMMAX and SHMALL kernel parameters values the ansible hugepages role sets shmmax, shmall, shmmni and hugepages as bundle.

kernel.shmmax=70% of RAM memory in Bytes
kernel.shmall= kernel.shmmax / kernel.shmmni

Also the oracle memlock limit is set to unlimited (both: soft and hard) as per the oracle recommendations

The algorithm used in the ansible hugepages role is the following:

if shmmax is not set in sysctl.conf
then
        set shmmax=70% of the RAM
        set shmmni= take the value from memory (usually the default is 4096)
        set shmall=shmmax/shmmni
         set hugepages=shmmax in MB/Hugepagesize in MB
         reload sysctl
else
      if shmmax < 70% of the RAM
      then
            set shmmax=70% of the RAM
            set shmmni= take the value from memory (usually the default is 4096)
            set shmall=shmmax/shmmni
            set hugepages=shmmax in MB/Hugepagesize in MB
            reload sysctl
       else
            if shmmax < total RAM
            then
                  set shmmni= take the value from memory (usually the default is 4096)
                  set shmall=shmmax/shmmni
                  set hugepages=shmmax in MB/Hugepagesize in MB
                  reload sysctt
             else
                   set shmmax=70% of the RAM
                   set shmmni= take the value from memory (usually the default is 4096)
                   set shmall=shmmax/shmmni
                   set hugepages=shmmax in MB/Hugepagesize in MB
                   reload sysctl
```

## Requirements

None.

## Role Variables

Available variables are listed below, along with default values (see 'defaults/main.yml'):

Default value for RAM percentage that we are using for shmmax

```
ram_pct_used: 70
```

## Dependencies

None.

## Example Playbook

```yaml
- hosts: all
  become: yes
  roles:
    - hugepages
```

## License

BSD

## Author Information

This role was created by Vladimir Naumovski - Oracle Database Consultant @Pythian
creation date: 07-2017
