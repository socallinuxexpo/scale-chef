#
# Cookbook Name:: scale_ssh
# Recipe:: default
#
# Copyright 2016, Southern California Linux Expo
#
# All rights reserved - Do Not Redistribute
#

package %w{openssh openssh-server openssh-clients} do
  action :upgrade
  notifies :restart, 'service[sshd]'
end

directory '/etc/ssh/authorized_keys' do
  owner 'root'
  group 'root'
  mode '0755'
end

scale_ssh_keys 'setup keys'

# If we're on vagrant, we need to copy the key to the new location
file '/etc/ssh/authorized_keys/vagrant' do
  only_if { ::File.exist?('/home/vagrant/.ssh/authorized_keys') }
  content lazy { File.read('/home/vagrant/.ssh/authorized_keys') }
  owner 'root'
  group 'root'
  mode '0644'
  action :create_if_missing
end

template '/etc/ssh/sshd_config' do
  source 'sshd_config.erb'
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, 'service[sshd]'
end

service 'sshd' do
  action [:enable, :start]
end
