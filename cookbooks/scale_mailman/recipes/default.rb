#
# Cookbook Name:: scale_mailman
# Recipe:: default
#

# iptables
node.default['fb_iptables']['filter']['INPUT']['rules']['allow_smtp'] = {
  'rule' => '-p tcp -m tcp -m conntrack --ctstate NEW --dport 25 -j ACCEPT',
}

# postfix
node.default['fb_postfix']['aliases']['listmaster'] =
  'listmaster@linuxfests.org'

node.default['fb_postfix']['main.cf']['inet_interfaces'] = "all"

{
  'mydestination' =>
    'lists.linuxfests.org, $myhostname, localhost.$mydomain, localhost',
  'mydomain' => 'linuxfests.org',
}.each do |conf, val|
  node.default['fb_postfix']['main.cf'][conf] = val
end

hname = "lists.socallinuxexpo.org"
{
  'smtpd_tls_cert_file' => FB::LetsEncrypt.cert(node, hname),
  'smtpd_tls_key_file' => FB::LetsEncrypt.key(node, hname),
  'smtpd_tls_security_level' => 'may',
}.each do |conf, val|
  node.default['fb_postfix']['main.cf'][conf] = val
end

include_recipe '::mailman3'

# some common stuff - backups, monitoring, service
template '/usr/local/bin/backup-mailman.sh' do
  owner 'root'
  group 'root'
  mode  '0755'
end

node.default['fb_cron']['jobs']['mailman_backups'] = {
  'time' => '0 4,20 * * *',
  'command' => '/usr/local/bin/backup-mailman.sh',
  'user' => 'mailman',
}

service 'mailman3' do
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
