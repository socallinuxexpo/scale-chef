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

cookbook_file '/etc/httpd/gd_bundle.crt' do
  owner 'root'
  group 'root'
  mode '0644'
end

file '/etc/httpd/sf_bundle.crt' do
  action :delete
end

{
  'allow_https' =>
    '-p tcp -m tcp -m conntrack --ctstate NEW --dport 443 -j ACCEPT',
  'allow_http' =>
    '-p tcp -m tcp -m conntrack --ctstate NEW --dport 80 -j ACCEPT',
}.each do |key, val|
  node.default['fb_iptables']['filter']['INPUT']['rules'][key] = {
    'rule' => val,
  }
end

# generate dev certs if we don't have prod ones
include_recipe 'scale_apache::dev'
