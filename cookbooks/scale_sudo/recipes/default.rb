# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
#
# Cookbook Name:: scale_sudo
# Recipe:: default
#

if node['fb_init']['vagrant']
  node.default['scale_sudo']['users']['vagrant'] = 'ALL=NOPASSWD: ALL'
end

package 'sudo' do
  action :upgrade
end

template '/etc/sudoers' do
  source 'sudoers.erb'
  mode '0440'
  owner 'root'
  group 'root'
end
