#
# Cookbook Name:: scale_apache
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

pkgs = %w{
  git
  httpd
  mod_ssl
  php
  php-gd
  php-mysql
  php-pdo
  php-xml
  python-boto
}

package pkgs do
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

cookbook_file '/usr/local/bin/deploy_legacy_sites' do
  source 'deploy_legacy_sites'
  owner 'root'
  group 'root'
  mode '0755'
end

# We don't want to deploy the site on every single run,
# but if we don't *have* the site yet, deploy it
execute '/usr/local/bin/deploy_site' do
  creates '/home/drupal/scale-drupal'
end

execute '/usr/local/bin/deploy_legacy_sites' do
  creates '/home/webroot/'
end

# Ensure existance of drupal directories
%w{
 /home/drupal/scale-drupal/httpdocs
 /home/drupal/scale-drupal/httpdocs/sites
 /home/drupal/scale-drupal/httpdocs/sites/default
 /home/webroot/
}.each do |tmpdir|
  directory tmpdir do
    owner 'root'
    group 'root'
    mode '0755'
  end
end

# Ensure existance of tmp directories required by drupal
%w{
 /home/drupal/scale-drupal/httpdocs/sites/default/files
 /home/drupal/scale-drupal/httpdocs/sites/default/files/css
 /home/drupal/scale-drupal/db
}.each do |tmpdir|
  directory tmpdir do
    owner 'root'
    group 'apache'
    mode '0775'
  end
end

template '/home/drupal/scale-drupal/httpdocs/sites/default/settings.php' do
  owner 'root'
  group 'apache'
  mode '0640'
end

template '/usr/local/bin/backup-drupal-static.sh' do
  owner 'root'
  group 'root'
  mode '0755'
  source 'backup-drupal-static.sh.erb'
end

template '/usr/local/bin/restore-drupal-static.py' do
  owner 'root'
  group 'root'
  mode '0755'
  source 'restore-drupal-static.py.erb'
end

execute '/usr/local/bin/restore-drupal-static.py' do
  creates '/home/drupal/scale-drupal/httpdocs/sites/default/files'
end

cookbook_file '/etc/httpd/sf_bundle.crt' do
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, 'service[httpd]'
end

# enforce perms
file '/etc/drupal_secrets' do
  owner 'root'
  group 'root'
  mode '0600'
end

node.default['fb_cron']['jobs']['drupal_backup'] = {
  'time' => '30 0,12 * * *',
  'command' => '/usr/local/bin/backup-drupal-static.sh'
}

include_recipe 'scale_apache::dev'

service 'httpd' do
  action [:enable, :start]
end
