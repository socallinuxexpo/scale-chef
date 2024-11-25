#
# Cookbook Name:: scale_mailman
# Recipe:: default
#

node.default['fb_iptables']['filter']['INPUT']['rules']['allow_smtp'] = {
  'rule' => '-p tcp -m tcp -m conntrack --ctstate NEW --dport 25 -j ACCEPT',
}

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
  python3
  python3-boto3
}

if node.centos8?
  pkgs += %w{
    php
    php-gd
    php-pdo
    php-xml
    php-mysqlnd
    python2
    python2-dns
    mailman
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
  pkgs += [
    'mailman3',
    # webui
    'hyperkitty',
    # admin ui
    'postorius',
    # glue between hyperkitty and postorius
    'python3-mailman-web',
    # new emails into archive
    'python-mailman-hyperkitty',
  ]
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

if node.centos8?
  cookbook_file '/usr/lib/mailman/bin/list_requests' do
    source 'list_requests'
    owner 'root'
    group 'mailman'
    mode '0755'
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

if node.centos8?
  link '/etc/mailman/sitelist.cfg' do
    to '/var/lib/mailman/data/sitelist.cfg'
  end

  template '/etc/mailman/mm_cfg.py' do
    source 'mm_cfg.py.erb'
    owner 'root'
    group 'root'
    mode  '0644'
  end
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

unless node.centos9?
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
end

service 'mailman' do
  service_name node.centos8? ? 'mailman' : 'mailman3'
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
