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

directory '/etc/chef' do
  owner 'root'
  group 'root'
  mode '0755'
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
  to '/etc/chef/client-prod.rb'
end

template '/etc/chef/runlist.json' do
  owner 'root'
  group 'root'
  mode '0644'
end

node.default['fb_cron']['jobs']['chef'] = {
  'time' => '*/15 * * * *',
  'command' => '/var/chef/repo/scale-chef/scripts/chefctl.sh -i'
}
