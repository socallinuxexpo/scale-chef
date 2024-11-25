#
# Cookbook Name:: scale_drupal
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

package 'drush' do
  only_if { node.centos7? }
  action :upgrade
end

package 'awscli' do
  only_if { node.centos8? }
  action :upgrade
end

# CentOS 10 doesn't yet have awscli2 and its dep python3-colorama
# due to https://issues.redhat.com/browse/RHEL-64923 which is simply
# a test failure, so we install the versions downloaded from Koji for now
base_url = 'https://kojihub.stream.centos.org/kojifiles/vol/koji02/packages'
colorama = "#{base_url}/python-colorama/0.4.6/13.el10/noarch" +
  '/python3-colorama-0.4.6-13.el10.noarch.rpm'
awscli2 = "#{base_url}/awscli2/2.17.18/4.el10/noarch" +
  '/awscli2-2.17.18-4.el10.noarch.rpm'

[colorama, awscli2].each do |url|
  fname = File.basename(url)
  src = "#{Chef::Config['file_cache_path']}/#{fname}"
  remote_file src do
    source url
  end

  package fname do
    source src
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

# new stuff is py3
restore_source = 'restore-drupal-static3.py.erb'
backup_source = 'backup-drupal-static3.sh.erb'

# support for older OSes until we finish upgrades/migrations
if node.centos6? || node.centos7?
  restore_source = 'restore-drupal-static.py.erb'
  backup_source = 'backup-drupal-static.sh.erb'
end

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

# enforce perms
file '/etc/drupal_secrets' do
  owner 'root'
  group 'root'
  mode '0600'
end

if node['env'] == 'prod'
    node.default['fb_cron']['jobs']['drupal_backup'] = {
      'time' => '30 0,12 * * *',
      'command' => '/usr/local/bin/backup-drupal-static.sh >/dev/null'
    }
end
