#
# Cookbook Name:: scale_ssh
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
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

execute 'copy vagrant key' do
  only_if { File.exists?('/home/vagrant/.ssh/authorized_keys') }
  command 'cp /home/vagrant/.ssh/authorized_keys /etc/ssh/authorized_keys/vagrant'
  creates '/etc/ssh/authorized_keys/vagrant'
end

file '/etc/ssh/authorized_keys/vagrant' do
  only_if { File.exists?('/etc/ssh/authorized_keys/vagrant') }
  owner 'root'
  group 'root'
  mode '0644'
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
