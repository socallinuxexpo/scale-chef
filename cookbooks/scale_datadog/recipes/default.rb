# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
#
# Cookbook Name:: scale_datadog
# Recipe:: default
#

cookbook_file '/etc/pki/rpm-gpg/DATADOG_RPM_KEY.public' do
  source 'DATADOG_RPM_KEY.public'
  owner 'root'
  group 'root'
  mode '0644'
end

cookbook_file '/etc/yum.repos.d/datadog.repo' do
  source 'datadog.repo'
  owner 'root'
  group 'root'
  mode '0644'
end

package 'datadog-agent' do
  action :upgrade
  notifies :restart, 'service[datadog-agent]'
end

directory '/etc/datadog-agent' do
  owner 'dd-agent'
  group 'dd-agent'
  mode '0755'
end

template '/etc/datadog-agent/datadog.yaml' do
  source 'datadog.yaml.erb'
  owner 'dd-agent'
  group 'dd-agent'
  mode '0640'
  notifies :restart, 'service[datadog-agent]'
end

directory '/etc/datadog-agent/conf.d' do
  owner 'dd-agent'
  group 'dd-agent'
  mode '0755'
end

scale_datadog_monitor_configs 'update monitor configs' do
  notifies :restart, 'service[datadog-agent]'
end

service 'datadog-agent' do
  # the normal ruby-stile exist-and-not-nil check makes Chef warn because a
  # string is returned inside of it, and it thinks you are trying to use a
  # shell-command-style only_if
  only_if { node['fb_init']['secrets']['datadog_api_key'] }
  action [:enable, :start]
end
