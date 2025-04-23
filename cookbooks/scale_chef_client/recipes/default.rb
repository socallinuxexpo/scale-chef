#
# Cookbook Name:: scale_chef_client
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

version = '18.7.3'
dl_plat = node.major_platform_version

rpm = "cinc-#{version}-1.el#{dl_plat}.x86_64.rpm"
rpmpath = File.join(Chef::Config['file_cache_path'], rpm)
remote_file rpmpath do
  source "http://downloads.cinc.sh/files/stable/cinc/#{version}/el/" +
    "#{dl_plat}/#{rpm}"
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

if ::File.symlink?('/etc/cinc') && !::File.symlink?('/etc/chef')
  symlink = '/etc/cinc'
  confdir = '/etc/chef'
elsif ::File.symlink?('/etc/chef') && !::File.symlink?('/etc/cinc')
  symlink = '/etc/chef'
  confdir = '/etc/cinc'
else
  fail 'Cannot determine which is the realdir /etc/cinc v /etc/chef'
end

[
  '/var/chef',
  confdir,
].each do |dir|
  directory dir do
    owner 'root'
    group 'root'
    mode '0755'
  end
end

link symlink do
  to confdir
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
    Chef::Config.from_file("#{confdir}/client.rb")
  end
  action :nothing
end

template "#{confdir}/client-prod.rb" do
  owner 'root'
  group 'root'
  mode '0644'
  notifies :create, 'ruby_block[reload_client_config]', :immediately
end

link "#{confdir}/client.rb" do
  # don't overwrite this if it's a link ot somewhere else, because
  # taste-tester
  not_if { File.symlink?("#{confdir}/client.rb") }
  to "#{confdir}/client-prod.rb"
end

link "#{confdir}/client.pem" do
  # don't overwrite this if it's a link ot somewhere else, because
  # taste-tester
  not_if { File.symlink?("#{confdir}/client.pem") }
  to "#{confdir}/client-prod.pem"
end

template "#{confdir}/runlist.json" do
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
      "-f #{confdir}/test_timestamp || /usr/local/sbin/chefctl -q &>/dev/null"
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
    'command' => '/usr/bin/find /var/log/chef -maxdepth 1 ' +
      '-name chef.2* -mtime +14 -exec /bin/rm -f {} \; &>/dev/null'
  },
}.each do |name, job|
  node.default['fb_cron']['jobs'][name] = job
end
