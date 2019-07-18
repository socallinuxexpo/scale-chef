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
  only_if { node['scale_datadog']['config']['api_key'] }
  action [:enable, :start]
end
