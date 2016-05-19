#
# Cookbook Name:: scale_apache
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

package ['httpd', 'mod_ssl', 'php'] do
  action :upgrade
  notifies :restart, 'service[httpd]'
end

# terrible hack, we should do something attribute driven here.
%w{
  default.conf
  ssl-default.conf
}.each do |conf|
  template "/etc/httpd/conf.d/#{conf}" do
    owner 'root'
    group 'root'
    mode '0644'
    notifies :restart, 'service[httpd]'
  end
end

%w{
  /home/drupal
}.each do |docroot|
  directory docroot do
    owner 'root'
    group 'root'
    mode '0755'
  end
end

cookbook_file '/usr/local/bin/deploy_site' do
  source 'deploy_site'
  owner 'root'
  group 'root'
  mode '0755'
end

# We don't want to deploy the site on every single run,
# but if we don't *have* the site yet, deploy it
execute '/usr/local/bin/deploy_site' do
  creates '/home/drupal/scale-drupal'
end

template '/home/drupal/scale-drupal/httpdocs/sites/default/settings.php' do
  owner 'root'
  group 'apache'
  mode '0640'
end

cookbook_file '/etc/httpd/sf_bundle.crt' do
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, 'service[httpd]'
end

include_recipe 'scale_apache::dev'

service 'httpd' do
  action [:enable, :start]
end
