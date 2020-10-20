Role Name
=========

Ansible Role: controlnode-provision

Provision the control node instance by installing and configuring:
* Squid for web proxying
* DNSMasq for DNS proxying
* Chrony for NTP services

This is required on bare metal instances as they are not connected directly to the internet, this instance will act as an http/dns proxy.

Requirements
------------

Review the Role Variables below and make the changes as required for the specific environment

Role Variables
--------------

* squid_cache_port: 3128 - default squid port
* ntp_servers: array of default NTP servers used by ntp service, defaults to ["169.254.169.254"]
* ntp_allow_from: array of IP prefixes from where the NTP server will allow queries
* dnsmasq_listen_addr: IP address on which DNSMasq will listen, to be updated with the bare metal interface
* dnsmasq_dns_servers: array of IP addresses where DNSMasq will forward requests to, defaults to ["169.254.169.254"]
* squid_listen_addr: IP address on which Squid will listen, to be updated with the bare metal interface
* squid_allow_from: IP prefixes which Squid allowes requests from, to be updated with the bare metal ranges
* remote_servers: array of IPs for the bare metal servers, to check connectivity at deployment time, defaults to ["127.0.0.1"]


Dependencies
------------

None.

Example Playbook
----------------

   - hosts: all
     become: yes
     roles:
       - controlnode-provision


