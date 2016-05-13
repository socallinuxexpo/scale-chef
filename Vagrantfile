# -*- mode: ruby -*-
# vi: set ft=ruby :

# eventually replace this with our own bootstrap
provisioning_script =
  "wget -qO- 'https://www.opscode.com/chef/install.sh' | bash"

required_plugins = [
  "vagrant-cachier",
  "vagrant-hostmanager",
]
required_plugins.each do |plugin|
  system "vagrant plugin install #{plugin}" unless Vagrant.has_plugin?(plugin)
end

Vagrant.configure("2") do |config|
  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.auto_detect = true
    config.cache.scope       = :box
  end

  if Vagrant.has_plugin?("vagrant-hostmanager")
    config.hostmanager.enabled = true
    config.hostmanager.manage_host = false
    config.hostmanager.ignore_private_ip = false
    config.hostmanager.include_offline = true
  else
    raise "vagrant-hostmanager plugin not found"
  end

  config.vm.box = 'bento/centos-7.2'

  config.vm.define "www" do |v|
    v.vm.hostname = "www"
    v.vm.network :private_network, ip: "172.16.1.10"
    v.vm.provision "shell", inline: provisioning_script
  end

  config.vm.define "db" do |v|
    v.vm.hostname = "db"
    v.vm.network :private_network, ip: "172.16.1.11"
    v.vm.provision "shell", inline: provisioning_script
  end

  config.vm.define "ldap" do |v|
    v.vm.hostname = "ldap"
    v.vm.network :private_network, ip: "172.16.1.12"
    v.vm.provision "shell", inline: provisioning_script
  end
end
