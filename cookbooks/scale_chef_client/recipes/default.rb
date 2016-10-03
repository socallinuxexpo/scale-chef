#
# Cookbook Name:: scale_chef_client
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

package 'chef' do
  action :upgrade
end

%w{
  /var/chef
  /var/chef/outputs
  /etc/chef
}.each do |dir|
  directory dir do
    owner 'root'
    group 'root'
    mode '0755'
  end
end

ruby_block 'reload_client_config' do
  block do
    Chef::Config.from_file('/etc/chef/client.rb')
  end
  action :nothing
end

template '/etc/chef/client-prod.rb' do
  owner 'root'
  group 'root'
  mode '0644'
  notifies :create, 'ruby_block[reload_client_config]', :immediately
end

link '/etc/chef/client.rb' do
  # don't overwrite this if it's a link ot somewhere else, because
  # taste-tester
  not_if { File.symlink?('/etc/chef/client.rb') }
  to '/etc/chef/client-prod.rb'
end

template '/etc/chef/runlist.json' do
  owner 'root'
  group 'root'
  mode '0644'
end

link '/usr/local/sbin/chefctl' do
  to '/var/chef/repo/scale-chef/scripts/chefctl.sh'
end

link '/usr/local/sbin/stop_chef_temporarily' do
  to '/var/chef/repo/scale-chef/scripts/stop_chef_temporarily'
end

{
  'chef' => {
    'time' => '*/15 * * * *',
    'command' => '/usr/bin/test -f /var/chef/cron.default.override -o ' +
      '-f /etc/chef/test_timestamp || /usr/local/sbin/chefctl -q'
  },
  'taste-untester' => {
    'time' => '*/5 * * * *',
    'command' => '/usr/local/sbin/taste-untester',
  },
  'remove override files' => {
    'time' => '*/5 * * * *',
    'command' => '/usr/bin/find /var/chef/ -maxdepth 1 ' +
      '-name cron.default.override -mmin +60 -exec /bin/rm -f {} \;'
  },
  # keep two weeks of chef run logs
  'cleanup chef logs' => {
    'time' => '1 1 * * *',
    'command' => '/usr/bin/find /var/chef/outputs -maxdepth 1 ' +
      '-name chef.2* -mtime +14 -exec /bin/rm -f {} \;'
  },
}.each do |name, job|
  node.default['fb_cron']['jobs'][name] = job
end
