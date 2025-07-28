#
# Cookbook Name:: scale_drupal
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

if node['hostname'] == 'scale-web-centos10'
  node.default['scale_drupal']['mysql_host'] =
    'scale-drupal.cluster-c19nohpiwnoo.us-east-1.rds.amazonaws.com'
  base_dir = 'httpdocs'
  settings_source = 'settings.php.erb'
elsif node['hostname'] == 'scale-web-centos10-newsite'
  node.default['scale_drupal']['mysql_host'] =
    'scale-drupal-newsite.cluster-c19nohpiwnoo.us-east-1.rds.amazonaws.com'
  base_dir = 'web'
  settings_source = 'settings-drupal10.php.erb'
end
settings_dest = "#{base_dir}/sites/default/settings.php"

package 'awscli2' do
  action :upgrade
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
%W{
 /home/drupal/scale-drupal/#{base_dir}
 /home/drupal/scale-drupal/#{base_dir}/sites
 /home/drupal/scale-drupal/#{base_dir}/sites/default
 /home/webroot/
}.each do |tmpdir|
  directory tmpdir do
    owner 'root'
    group 'root'
    mode '0755'
  end
end

# Ensure existance of tmp directories required by drupal
%W{
 /home/drupal/scale-drupal/#{base_dir}/sites/default/files
 /home/drupal/scale-drupal/#{base_dir}/sites/default/files/css
 /home/drupal/scale-drupal/db
}.each do |tmpdir|
  directory tmpdir do
    owner 'root'
    group 'apache'
    mode '0775'
  end
end

template "/home/drupal/scale-drupal/#{settings_dest}" do
  source settings_source
  owner 'root'
  group 'apache'
  mode '0640'
end

# new stuff is py3
restore_source = 'restore-drupal-static3.py.erb'
backup_source = 'backup-drupal-static3.sh.erb'

template '/usr/local/bin/backup-drupal-static.sh' do
  owner 'root'
  group 'root'
  mode '0755'
  source backup_source
end

template '/usr/local/bin/restore-drupal-static.py' do
  owner 'root'
  group 'root'
  mode '0755'
  source restore_source
end

execute '/usr/local/bin/restore-drupal-static.py' do
  creates '/home/drupal/scale-drupal/httpdocs/sites/default/files'
end

if node['env'] == 'prod'
    node.default['fb_cron']['jobs']['drupal_backup'] = {
      'time' => '30 0,12 * * *',
      'command' => '/usr/local/bin/backup-drupal-static.sh >/dev/null'
    }
end
