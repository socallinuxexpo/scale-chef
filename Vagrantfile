# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # vagrant plugin install vagrant-cachier
  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.auto_detect = true
    config.cache.scope       = :box
  end

  # vagrant plugin install vagrant-hostmanager
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = false
  config.hostmanager.ignore_private_ip = false
  config.hostmanager.include_offline = true

  config.vm.box = 'bento/centos-7.2'

  config.vm.define "www" do |v|
    v.vm.hostname = "www"
    v.vm.network :private_network, ip: "172.16.1.10"
  end

  config.vm.define "db" do |v|
    v.vm.hostname = "db"
    v.vm.network :private_network, ip: "172.16.1.11"
  end

  config.vm.define "ldap" do |v|
    v.vm.hostname = "ldap"
    v.vm.network :private_network, ip: "172.16.1.12"
  end
end
