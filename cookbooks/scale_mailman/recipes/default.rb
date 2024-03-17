#
# Cookbook Name:: scale_mailman
# Recipe:: default
#

node.default['fb_iptables']['filter']['INPUT']['rules']['allow_smtp'] = {
  'rule' => '-p tcp -m tcp -m conntrack --ctstate NEW --dport 25 -j ACCEPT',
}

# for PHP (phplist)
node.default['fb_apache']['mpm'] = 'prefork'
node.default['fb_apache']['modules'] << 'cgi'
node.default['fb_apache']['modules_mapping']['cgi'] = "mod_cgi.so"

node.default['scale_apache']['ssl_hostname'] = 'lists.socallinuxexpo.org'

include_recipe 'scale_apache::simple'

common_config = {
  'ServerName' => 'lists.socallinuxexpo.org',
  'ServerAlias' => [
    'lists.socallinuxexpo.net',
    'lists.socallinuxexpo.com',
    'lists.linuxfests.org',
    'lists.linuxfests.net',
    'lists.linuxfests.com',
  ],
}

node.default['fb_apache']['sites']['*:80'] = common_config.merge({
  'Redirect permanent /' => 'https://lists.linuxfests.org/',
})

allow_all = {
  'AllowOverride' => 'None',
  'Order' => 'allow,deny',
  'Allow' => 'from all',
  'Require' => 'all granted',
}

common_config.merge({
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
}).each do |key, val|
  node.default['fb_apache']['sites']['_default_:443'][key] = val
end

pkgs = %w{
  php
  php-gd
  php-pdo
  php-xml
}

if node.centos7?
  pkgs += %w{
    awscli
    php-mysql
    python-dns
    python2-boto
  }
elsif node.centos8?
  pkgs += %w{
    php-mysqlnd
    python2
    python2-dns
    python3
    python3-boto3
  }

  node.default['fb_dnf']['modules']['python27'] = {
    'enable' => true,
    'stream' => '2.7',
  }
  node.default['fb_dnf']['modules']['python36'] = {
    'enable' => true,
    'stream' => '3.6',
  }
  node.default['fb_dnf']['modules']['mailman'] = {
    'enable' => true,
    'stream' => '2.1',
  }
else
  fail "scale_mailman: platform not supported"
end

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

cookbook_file '/usr/lib/mailman/bin/list_requests' do
  source 'list_requests'
  owner 'root'
  group 'mailman'
  mode '0755'
end

if node.centos7?
  # CentOS 7's version of mailman only has 2.1.15, but that doesn't have any of
  # the necessary features for accepting mail from people with dmarc policies
  # (https://wiki.list.org/DEV/DMARC)
  #
  # those only were added in 2.1.16. 2.1.18 and later releases. Thus, using the
  # C7 version would mean:
  # - emails from people with strict dmarc policies (eg @yahoo.com or
  # owen@delong.com) emails will just bounce back when mailman tries to send it
  # to list members. the receiving members will then be unsubscribed from the
  # list instead of the sender.
  # - for those that dont have reject set as their policy, but rather quarantine
  # their mail will go to spam As such we've pulled 2.1.21 from FC25

  mailman_file = 'mailman-2.1.21-1.fc25.x86_64.rpm'
  remote_file "#{Chef::Config['file_cache_path']}/#{mailman_file}" do
    not_if { File.exists?('/usr/lib/mailman/bin/mailmanctl') }
    source "https://s3.amazonaws.com/scale-packages/#{mailman_file}"
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end
end

package 'mailman' do
  if node.centos7?
    not_if { File.exists?('/usr/lib/mailman/bin/mailmanctl') }
    source "#{Chef::Config['file_cache_path']}/mailman-2.1.21-1.fc25.x86_64.rpm"
  else
    action :upgrade
  end
end

## RESTORE BACKUPS
if node.centos7?
  # Probably never worked... but also would need a port to boto3 to even
  # try to work in C8
  template '/usr/local/bin/restore-mailman.py' do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  execute '/usr/local/bin/restore-mailman.py' do
    creates '/var/lib/mailman/archives/private/tech'
  end
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

node.default['fb_postfix']['aliases']['listmaster'] =
  'listmaster@linuxfests.org'

node.default['fb_postfix']['main.cf']['alias_maps'] <<
  ',hash:/var/lib/mailman/data/aliases'

node.default['fb_postfix']['main.cf']['inet_interfaces'] = "all"

{
  'mydestination' =>
    'lists.linuxfests.org, $myhostname, localhost.$mydomain, localhost',
  'mydomain' => 'linuxfests.org',
}.each do |conf, val|
  node.default['fb_postfix']['main.cf'][conf] = val
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
