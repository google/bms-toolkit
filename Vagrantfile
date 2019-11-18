# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

require 'yaml'
require "fileutils"
require "ipaddr"
require "json"

# Read YAML file with VM configuration
servers = YAML.load_file('hosts.yml')

# Get host timezone
offset_sec = Time.now.gmt_offset
if (offset_sec % (60 * 60)) == 0
  offset_hr = ((offset_sec / 60) / 60)
  timezone_suffix = offset_hr >= 0 ? "-#{offset_hr.to_s}" : "+#{(-offset_hr).to_s}"
  SYSTEM_TIMEZONE = 'Etc/GMT' + timezone_suffix
else
  # if host time zone isn't an integer hour offset, fall back to UTC
  SYSTEM_TIMEZONE = 'UTC'
end

# Get default disk path
line = `VBoxManage list systemproperties | grep "Default machine folder"`
vb_machine_folder = line.split(':')[1].strip()

# Create inventory file for Ansible by reading the hosts.yml
#f = File.open("inventory","w")
#servers.each do |vm|
# f.puts "[#{vm["hostgroup"]}]"
#  (1..vm['num_vm']).each do |v|
#    hostname = "#{vm['basename_vm']}#{v}"
#    baseip = IPAddr.new vm['base_pub_ip'] unless vm['base_pub_ip'].nil?
#    basevipip = IPAddr.new vm['base_pub_ip_vip'] unless vm['base_pub_ip_vip'].nil? || vm['base_pub_ip'].nil?
#    address = baseip.to_i+v-1 unless vm['base_pub_ip'].nil?
#    vipaddress = basevipip.to_i+v-1 unless vm['base_pub_ip_vip'].nil? || vm['base_pub_ip'].nil?
#    pubip= [24, 16, 8, 0].collect {|b| (address >> b) & 255}.join('.') unless vm['base_pub_ip'].nil?
#    vipip = [24, 16, 8, 0].collect {|c| (vipaddress >> c) & 255}.join('.') unless vm['base_pub_ip_vip'].nil? || vm['base_pub_ip'].nil?
#    fwdport = "220#{v}"
#    f.puts hostname + " ansible_ssh_host=127.0.0.1 ansible_port=" + fwdport + " ansible_ssh_user=" + vm["vagrant_user"] + " ansible_ssh_private_key_file=.vagrant/machines/" + hostname + "/virtualbox/private_key ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" if (not vm['vagrant_private_key'] and not vm['base_pub_ip'])
#    f.puts hostname + " ansible_ssh_host=" + pubip + " ansible_ssh_user=" + vm["vagrant_user"] + " ansible_ssh_private_key_file=.vagrant/machines/" + hostname + "/virtualbox/private_key ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" if (not vm['vagrant_private_key'] and vm['base_pub_ip'])
#    f.puts hostname + " ansible_ssh_host=" + pubip + " ansible_ssh_user=" + vm["vagrant_user"] + " ansible_ssh_private_key_file=" + vm["vagrant_private_key"] + " ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" if (vm['vagrant_private_key'] and not vm['base_pub_ip_vip'])
#    f.puts hostname + " ansible_ssh_host=" + pubip + " ansible_ssh_user=" + vm["vagrant_user"] + " ansible_ssh_private_key_file=" + vm["vagrant_private_key"] + " ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" + " vip=" + vipip unless vm['vagrant_private_key'].nil? || vm['base_pub_ip_vip'].nil?
#    f.puts hostname + " ansible_ssh_host=" + pubip + " ansible_ssh_user=" + vm["vagrant_user"] + " ansible_ssh_pass=" + vm["vagrant_pass"] + " ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" + " vip=" + vipip unless vm['vagrant_pass'].nil? || vm['base_pub_ip_vip'].nil?
#    f.puts hostname + " ansible_ssh_host=" + pubip + " ansible_ssh_user=" + vm["vagrant_user"] + " ansible_ssh_pass=" + vm["vagrant_pass"] + " ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" if (vm['vagrant_pass'] and not vm['base_pub_ip_vip'])
#  end
#  f.puts
#  f.puts "[#{vm["hostgroup"]}:vars]" unless vm["domain"].nil?
#  f.puts "domain=" +  vm["domain"] unless vm["domain"].nil?
#  f.puts "scan_addresses=" + vm["scan_addresses"] unless vm["scan_addresses"].nil?
#  f.puts "hostgroup=" + vm["hostgroup"] unless vm["hostgroup"].nil?
#  f.puts
#end
#f.close

# Create VMs
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
config.vm.boot_timeout = 600
config.vm.box_check_update = false
#config.ssh.insert_key = false
config.vm.provider :virtualbox do |vb|
  vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
end

# Mount shared folders
servers.each do |vm|
  if vm['synced_folders']
    config.vm.synced_folder '.', '/vagrant', disabled: true
    vm['synced_folders'].each do |f|
      if File.directory?("#{f['src']}")
        config.vm.synced_folder "#{f['src']}", "#{f['dest']}", :mount_options => ["dmode=777","fmode=777"]
      end
    end
  end
end

servers.each_with_index do |vm,index|

    (1..vm['num_vm']).each_with_index do |v,index|
        v=vm['num_vm']+1-v
        num_vms=v
        check = index+num_vms
        hostname = "#{vm['basename_vm']}#{v}"
        hostgroup = "#{vm['hostgroup']}"
        base_disk_path = "#{vm['base_disk_path']}" unless vm['base_disk_path'].nil?
        domain = "#{vm['domain']}"
        provisioning = vm['provisioning'] unless vm['provisioning'].nil?
        provisioning_env_override = vm['provisioning_env_override'] unless vm['provisioning_env_override'].nil?
        baseip_pub = IPAddr.new vm['base_pub_ip']
        baseip_priv = IPAddr.new vm['base_priv_ip'] unless vm['base_priv_ip'].nil?
        pub_address = baseip_pub.to_i+v-1
        priv_address = baseip_priv.to_i+v-1 unless vm['base_priv_ip'].nil?
        pubip = [24, 16, 8, 0].collect {|b| (pub_address >> b) & 255}.join('.')
        privip = [24, 16, 8, 0].collect {|b| (priv_address >> b) & 255}.join('.') unless vm['base_priv_ip'].nil?
        config.vm.define hostname do |srv|
          srv.vm.box = vm["box"]
          srv.vm.box_version = vm["box_version"] unless vm['box_version'].nil?
          srv.vm.box_url = vm["box_url"] unless vm['box_url'].nil?
          srv.vm.hostname = hostname
          srv.vm.network "private_network", ip: pubip
          srv.vm.network "private_network", ip: privip unless privip.nil?
          srv.vm.provider :virtualbox do |vb|
              vb.name = hostname
              vb.memory = vm["ram"]
              vb.cpus = vm["cpu"]
              # Unlike ol7-latest, generic/rhel7 doesn't include a SATA controller or sdb for ADR so adding:
              unless File.exist?(File.expand_path("#{vb_machine_folder}/#{hostgroup}/#{vm['basename_vm']}1/#{vm['basename_vm']}1.vbox"))
                vb.customize ["storagectl", :id, "--name", "SATA Controller", "--add", "sata"] if (vm["box"] == 'generic/rhel7')
              end
              #vb.customize ["storagectl", :id, "--name", "SATA Controller", "--add", "sata"] if (vm["box"] == 'generic/rhel7')
              vb.customize ["modifyvm", :id, "--groups", "/#{hostgroup}"] unless vm["hostgroup"].nil?
              if vm['create_local_disk']
                  FileUtils.mkdir_p "#{base_disk_path}/#{hostgroup}" unless vm['base_disk_path'].nil?
                  portnum = 0
                  vm['local_disks'].each do |disk|
                  d = 0
                  while d < disk['count']
                       d += 1
                       portnum += 1
                       #local_disk_name = "#{base_disk_path}/#{hostgroup}/#{vm['basename_vm']}#{v}-#{disk['name']}-#{d}.vdi" if vm["base_disk_path"]
                       local_disk_name = "#{vb_machine_folder}/#{hostgroup}/#{vm['basename_vm']}#{v}-#{disk['name']}-#{d}.vdi" if vm["base_disk_path"]
                       local_disk_name = "#{vb_machine_folder}/#{hostgroup}/#{vm['basename_vm']}#{v}-#{disk['name']}-#{d}.vdi" if not vm["base_disk_path"]
                       size = disk['size']
                       variant = disk['variant']
                       if !File.exist?(local_disk_name)
                         vb.customize ['createhd', '--filename', "#{local_disk_name}", '--variant', variant, '--size', size * 1024]
                       end
                       vb.customize ['storageattach', :id,  '--storagectl', "SATA Controller", '--port', portnum, '--device', 0, '--type', 'hdd', '--medium', "#{local_disk_name}"]
                  end
                end
              end
              if vm['create_shared_disk']
                portnum = 0
                vm['local_disks'].each { |key| portnum += key['count'] } if vm['create_local_disk']
                vm['shared_disks'].each do |disk|
                  d = 0
                  while d < disk['count']
                       d += 1
                       portnum += 1
                       shared_disk_name = "#{base_disk_path}/#{hostgroup}/#{vm['hostgroup']}-shared-#{disk['name']}-#{d}.vdi" if vm["base_disk_path"]
                       shared_disk_name = "#{vm['hostgroup']}-shared-#{disk['name']}-#{d}.vdi" if not vm["base_disk_path"]
                       size = disk['size']
                       if !File.exist?(shared_disk_name) and check == v  # Only create the disk as the first VM is created
                         vb.customize ['createhd', '--filename', "#{shared_disk_name}", '--variant', 'fixed', '--size', size * 1024]
                         vb.customize ['modifyhd', "#{shared_disk_name}", '--type', 'shareable']
                       end
                       vb.customize ['storageattach', :id,  '--storagectl', "SATA Controller", '--port', portnum, '--device', 0, '--type', 'hdd', '--medium', "#{shared_disk_name}"]
                  end
                end
              end
            end
            if ARGV[0] == "up"
              config.vm.provision "network", type: "shell", inline: "service network restart", run: "always" # This is because EL7 doesn't always 'start' the host-only networks
            end
            #if hostname == "#{vm['basename_vm']}1"
            #  srv.vm.provision "ansible_local", run: "always" do |ansible| # This will also try to install Ansible if it does not already exist
            #    ansible.playbook = "base-provision/init.yml"
            #    ansible.inventory_path = "inventory"
            #    ansible.limit = "#{hostgroup}"
            #  end
            #end # end if

            if provisioning and ENV['setup'] == 'true'
              # if vm['create_shared_disk'] # If shared disks, assume RAC install -> configure master_node at hostlevel
              #   srv.vm.provision "hostvars", type: "shell", inline: "echo 'master_node: true' > /vagrant/extra-provision/ansible-oracle/host_vars/#{hostname}" if hostname == "#{vm['basename_vm']}1"       # sets up a 'master' node for RAC installs
              #   srv.vm.provision "hostvars", type: "shell", inline: "echo 'master_node: false' > /vagrant/extra-provision/ansible-oracle/host_vars/#{hostname}" unless hostname == "#{vm['basename_vm']}1"
              # end
              if hostname == "#{vm['basename_vm']}1" # Run the provisioning step once, for all hosts in group. Only run on the 'first' node (lowest number), let Ansible do the parallelism
                srv.vm.provision "ansible_local" do |ansible|
                  ansible.playbook = "#{provisioning}"
                  ansible.inventory_path = "inventory"
                  ansible.limit = "#{hostgroup}"
                  if provisioning_env_override
                  ansible.extra_vars = {
                    oracle_scan: "#{hostgroup}.#{domain}",
                    oracle_install_version_gi: "#{GIVER}",
                    #apply_patches_gi: "#{APPLY_PATCHES_GI}",
                    #apply_patches_db: "#{APPLY_PATCHES_DB}",
                    db_homes_config: {"db1":{
                    home: "db1",
                    version: "#{DBVER}",
                    edition: "EE",
                    }},
                    db_homes_installed: "#{DB_HOMES_INSTALLED.to_json}",
                    oracle_databases: "#{ORACLE_DATABASES.to_json}"
                  }
                end
                end # End provisioning step
              end # end if
            end # end provisioning
            # Run pre-ansible setup scripts within guest:
            #srv.vm.provision "shell", inline: "echo '----> Starting VM pre-ansible installations scripts <----'"
            #srv.vm.provision "shell", path: "vagrant_setup/setup.sh", env:
            #  {
            #    "SYSTEM_TIMEZONE"     => SYSTEM_TIMEZONE
            #  }
            #srv.vm.provision "shell", inline: "echo '----> VM pre-ansible installation script complete <----'"
          end
      end #end config
    end
end
