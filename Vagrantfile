# -*- mode: ruby -*-
# vi: set ft=ruby :

commands = [
  # hack for https://github.com/mitchellh/vagrant/issues/1303
  "echo 'Defaults env_keep += \"SSH_AUTH_SOCK\"' | sudo tee /etc/sudoers.d/agent",
  # add github ssh hostkey
  "[ -d /root/.ssh ] || sudo mkdir -p -m 0700 /root/.ssh && ssh-keyscan -H github.com | sudo tee /root/.ssh/known_hosts",
  # bootstrap chef
  "[ -f /etc/chef/client.rb ] || sudo /vagrant/scripts/chefctl.sh -b",
  # run chef
  "sudo /var/chef/repo/scale-chef/scripts/chefctl.sh -i",
]
provisioning_script = commands.join("; ")

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

  config.ssh.forward_agent = true

  config.vm.box = 'bento/centos-7.2'

  config.vm.define "www1" do |v|
    v.vm.hostname = "www1"
    v.vm.network :private_network, ip: "172.16.1.10"
    v.vm.provision "shell", inline: provisioning_script, privileged: false
  end

  config.vm.define "db1" do |v|
    v.vm.hostname = "db1"
    v.vm.network :private_network, ip: "172.16.1.11"
    v.vm.provision "shell", inline: provisioning_script, privileged: false
  end
end
