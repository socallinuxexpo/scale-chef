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

directory '/etc/dd-agent' do
  owner 'root'
  group 'root'
  mode '0755'
end

template '/etc/dd-agent/datadog.conf' do
  source 'datadog.conf.erb'
  owner 'root'
  group 'dd-agent'
  mode '0640'
  notifies :restart, 'service[datadog-agent]'
end

Dir.glob('/etc/dd-agent/conf.d/*.yaml').each do |f|
  basename = File.basename(f, '.yaml')
  file f do
    not_if { node['scale_datadog']['monitors'].keys.include?(basename) }
    action :delete
    notifies :restart, 'service[datadog-agent]'
  end
end

scale_datadog_monitor_configs 'update monitor configs' do
  notifies :restart, 'service[datadog-agent]'
end

service 'datadog-agent' do
  only_if { node['scale_datadog']['config']['api_key'] }
  action [:enable, :start]
end
