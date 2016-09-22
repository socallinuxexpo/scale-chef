#
# Cookbook Name:: scale_mailman
# Recipe:: default
#

include_recipe 'scale_apache::simple'

allow_all = {
  'AllowOverride' => 'None',
  'Order' => 'allow,deny',
  'Allow' => 'from all',
  'Require' => 'all granted',
}
{
  'ScriptAlias' => '/cgi-bin/mailman/ /usr/lib/mailman/cgi-bin/',
  'Alias /pipermail/' => '/var/lib/mailman/archives/public/',
  'Alias /images/mailman/' => '/usr/lib/mailman/icons/',
  'Directory /usr/lib/mailman/cgi-bin/' => {
    'Options' => 'ExecCGI',
    'AddHandler' => 'cgi-script .cgi',
  }.merge!(allow_all),
  'Directory /var/lib/mailman/archives/public/' => {
    'Options' => 'FollowSymlinks',
  }.merge!(allow_all),
  'Directory /usr/lib/mailman/icons/' => allow_all,
}.each do |key, val|
  node.default['fb_apache']['sites']['*:80'][key] = val
end

pkgs = %w{
  php
  php-gd
  php-mysql
  php-pdo
  php-xml
  python-dns
  python-boto
}
package pkgs do
  action :upgrade
  notifies :restart, 'service[apache]'
end

cookbook_file '/var/www/html/index.html' do
  source 'index.html'
  owner 'root'
  group 'root'
  mode '0644'
end

remote_file "#{Chef::Config['file_cache_path']}/mailman-2.1.21-1.fc25.x86_64.rpm" do
  not_if { File.exists?('/usr/lib/mailman/bin/mailmanctl') }
  source 'https://s3.amazonaws.com/scale-packages/mailman-2.1.21-1.fc25.x86_64.rpm'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

package 'mailman' do
  not_if { File.exists?('/usr/lib/mailman/bin/mailmanctl') }
  source "#{Chef::Config['file_cache_path']}/mailman-2.1.21-1.fc25.x86_64.rpm"
end

## RESTORE BACKUPS
template '/usr/local/bin/restore-mailman.py' do
  owner 'root'
  group 'root'
  mode  '0755'
end

execute '/usr/local/bin/restore-mailman.py' do
  creates '/var/lib/mailman/archives/'
end

template '/usr/local/bin/backup-mailman.sh' do
  owner 'root'
  group 'root'
  mode  '0755'
end

file '/etc/cron.d/mailman' do
  action :delete
end

link '/etc/mailman/sitelist.cfg' do
  to '/var/lib/mailman/data/sitelist.cfg'
end

template '/etc/mailman/mm_cfg.py' do
  source 'mm_cfg.py.erb'
  owner 'root'
  group 'root'
  mode  '0644'
end

node.default['fb_cron']['jobs']['mailman_backups'] = {
  'time' => '0 4,20 * * *',
  'command' => '/usr/local/bin/backup-mailman.sh',
  'user' => 'mailman',
}

node.default['fb_cron']['jobs']['mailman_checkdbs'] = {
  'time' => '0 8 * * *',
  'command' => '/usr/lib/mailman/cron/checkdbs',
  'user' => 'mailman',
}

node.default['fb_cron']['jobs']['mailman_disabled'] = {
  'time' => '0 9 * * *',
  'command' => '/usr/lib/mailman/cron/disabled',
  'user' => 'mailman',
}

node.default['fb_cron']['jobs']['mailman_senddigests'] = {
  'time' => '0 12 * * *',
  'command' => '/usr/lib/mailman/cron/senddigests',
  'user' => 'mailman',
}

node.default['fb_cron']['jobs']['mailman_mailpasswds'] = {
  'time' => '0 5 1 * *',
  'command' => '/usr/lib/mailman/cron/mailpasswds',
  'user' => 'mailman',
}

node.default['fb_cron']['jobs']['mailman_gate_news'] = {
  'time' => '0,5,10,15,20,25,30,35,40,45,50,55 * * * *',
  'command' => '/usr/lib/mailman/cron/gate_news',
  'user' => 'mailman',
}

node.default['fb_cron']['jobs']['mailman_nightly_gzip'] = {
  'time' => '27 3 * * *',
  'command' => '/usr/lib/mailman/cron/nightly_gzip',
  'user' => 'mailman',
}

node.default['fb_cron']['jobs']['mailman_cull_bad_shunt'] = {
  'time' => '30 4 * * *',
  'command' => '/usr/lib/mailman/cron/cull_bad_shunt',
  'user' => 'mailman',
}

include_recipe 'scale_apache::dev'

node.default['scale_postfix']['aliases']['listmaster'] = 'listmaster@linuxfests.org'

node.default['scale_postfix']['main.cf']['alias_maps'] <<
  'hash:/var/lib/mailman/data/aliases'

{
  'mydestination' =>
    'lists.linuxfests.org, $myhostname, localhost.$mydomain, localhost',
  'mydomain' => 'linuxfests.org',
}.each do |conf, val|
  node.default['scale_postfix']['main.cf'][conf] = val
end

template '/var/lib/mailman/data/aliases' do
  owner 'root'
  group 'root'
  mode '0644'
  notifies :run, 'execute[update mailman aliases]', :immediately
end

execute 'update mailman aliases' do
  command 'postalias /var/lib/mailman/data/aliases'
  action :nothing
end

service 'mailman' do
  action [:enable, :start]
end

node.default['scale_datadog']['monitors']['apache'] = {
  'init_config' => nil,
  'instances' => [{ 'apache_status_url' =>
      'http://localhost/server-status?auto' }],
}

node.default['scale_datadog']['monitors']['dns_check'] = {
  'init_config' => { 'default_timeout' => 4 },
  'instances' => [{ 'hostname' => 'lists.linuxfests.org',
                    'nameserver' => '8.8.8.8',
                    'timeout' => 8 }],
}

node.default['scale_datadog']['monitors']['linux_proc_extras'] = {
  'init_config' => nil, 'instances' => [{ 'tags' => [] }]
}

node.default['scale_datadog']['monitors']['http_check'] = {
  'init_config' => nil,
  'instances' => [{ 'name' => 'lists.linuxfests.org',
                    'url' => 'http://lists.linuxfests.org',
                    'timeout' => 2 }],
}
