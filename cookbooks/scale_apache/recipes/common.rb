#
# Cookbook Name:: scale_apache
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

directory '/etc/httpd' do
  owner 'root'
  group 'root'
  mode '0755'
end

cookbook_file '/etc/httpd/sf_bundle.crt' do
  owner 'root'
  group 'root'
  mode '0644'
end
