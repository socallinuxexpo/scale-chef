#
# Cookbook Name:: scale_chef_client
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

# omfg I hate this so much
version = '17.10.0'
rpm = "cinc-#{version}-1.el#{node.major_platform_version}.x86_64.rpm"
rpmpath = File.join(Chef::Config['file_cache_path'], rpm)
remote_file rpmpath do
  source "http://downloads.cinc.sh/files/stable/cinc/#{version}/el/" +
    "#{node.major_platform_version}/#{rpm}"
  owner 'root'
  group 'root'
  mode '0644'
end

ruby_block 'reexec chef' do
  block do
    exec('/opt/cinc/bin/cinc-client --no-fork')
  end
  action :nothing
end

package 'cinc' do
  # We need the gate otherwise whyrun breaks
  only_if { File.exists?(rpmpath) }
  source rpmpath
  action :upgrade
  notifies :run, 'ruby_block[reexec chef]', :immediately
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

link '/etc/cinc' do
  to '/etc/chef'
end

%w{
  chef-apply
  chef-client
  chef-shell
  chef-solo
}.each do |f|
  link "/usr/bin/#{f}" do
    to '/opt/cinc/bin/cinc-wrapper'
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

link '/etc/chef/client.pem' do
  # don't overwrite this if it's a link ot somewhere else, because
  # taste-tester
  not_if { File.symlink?('/etc/chef/client.pem') }
  to '/etc/chef/client-prod.pem'
end

template '/etc/chef/runlist.json' do
  owner 'root'
  group 'root'
  mode '0644'
end

cookbook_file '/usr/local/sbin/taste-untester' do
  owner 'root'
  group 'root'
  mode '0755'
end

include_recipe '::chefctl'

link '/usr/local/sbin/stop_chef_temporarily' do
  only_if { ::File.symlink?('/usr/local/sbin/stop_chef_temporarily') }
  action :delete
end

cookbook_file '/usr/local/sbin/stop_chef_temporarily' do
  owner 'root'
  group 'root'
  mode '0755'
end

{
  'chef' => {
    'time' => '*/15 * * * *',
    'command' => '/usr/bin/test -f /var/chef/cron.default.override -o ' +
      '-f /etc/chef/test_timestamp || /usr/local/sbin/chefctl -q &>/dev/null'
  },
  'taste-untester' => {
    'time' => '*/5 * * * *',
    'command' => '/usr/local/sbin/taste-untester &>/dev/null',
  },
  'remove override files' => {
    'time' => '*/5 * * * *',
    'command' => '/usr/bin/find /var/chef/ -maxdepth 1 ' +
      '-name cron.default.override -mmin +60 -exec /bin/rm -f {} \; &>/dev/null'
  },
  # keep two weeks of chef run logs
  'cleanup chef logs' => {
    'time' => '1 1 * * *',
    'command' => '/usr/bin/find /var/chef/outputs -maxdepth 1 ' +
      '-name chef.2* -mtime +14 -exec /bin/rm -f {} \; &>/dev/null'
  },
}.each do |name, job|
  node.default['fb_cron']['jobs'][name] = job
end
