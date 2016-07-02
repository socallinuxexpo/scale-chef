#
# Cookbook Name:: scale_postfix
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

pkgs = %w{
  postfix
  postfix-perl-scripts
}

package pkgs do
  action :upgrade
end

template '/etc/postfix/main.cf' do
  owner 'root'
  group 'root'
  mode  '0644'
  notifies :restart, 'service[postfix]', :immediately
end

template '/etc/postfix/aliases' do
  source 'aliases.erb'
  owner 'root'
  group 'root'
  mode  '0644'
  notifies :run, 'execute[newaliases]', :immediately
end

execute 'newaliases' do
  action :nothing
  notifies :restart, 'service[postfix]', :immediately
end

service 'postfix' do
  action [:enable, :start]
end

# Cleanup compat stuff
file '/etc/aliases' do
  action :delete
end
