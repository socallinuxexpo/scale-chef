# This is where you set your own stuff...

node.default['scale_chef_client']['cookbook_dirs'] = [
  '/var/chef/repo/cookbooks',
]
node.default['scale_chef_client']['role_dir'] =
  '/var/chef/repo/roles'

if node.vagrant?
  node.default['scale_sudo']['users']['vagrant'] = 'ALL=NOPASSWD: ALL'
end

d = {}
if File.exists?('/etc/datadog_secrets')
  File.read('/etc/datadog_secrets').each_line do |line|
    k, v = line.strip.split(/\s*=\s*/)
    d[k.downcase] = v
  end
  if d['application_key']
    node.default['scale_datadog']['config']['application_key'] =
      d['application_key']
  end
  if d['api_key']
    node.default['scale_datadog']['config']['api_key'] = d['api_key']
  end
end

{
  'abuse' => 'postmaster',
  'decode' => 'root',
  'postmaster' => 'root',
  'root' => 'root@socallinuxexpo.org',
  'scale-voicemail' => 'scale-chairs',
  'spam' => 'postmaster',
  'MAILER-DAEMON' => 'postmaster',
}.each do |src, dst|
  node.default['fb_postfix']['aliases'][src] = dst
end

if File.exist?('/etc/postfix/skip_mailgun')
  Chef::Log.warn("fb_init: Skipping mailgun postfix setup!")
elsif File.exist?('/etc/sasl_passwd')
  {
    'smtp_sasl_auth_enable' => 'yes',
    'relayhost' => 'smtp.mailgun.org:2525',
    'smtp_sasl_security_options' => 'noanonymous',
    'smtp_sasl_password_maps' => 'hash:/etc/postfix/sasl_passwd',
  }.each do |k, v|
    node.default['fb_postfix']['main.cf'][k] = v
  end

  node.default['fb_postfix']['sasl_passwd']['smtp.mailgun.org:2525'] =
    File.read('/etc/sasl_passwd').chomp.split(' ')[1]
else
  fail 'fb_init: /etc/sasl_passwd is missing, cannot setup mailgun'
end

node.default['fb_postfix']['main.cf']['mydomain'] = 'localhost'

package %w{postfix-perl-scripts cyrus-sasl-plain cyrus-sasl-md5} do
  action :upgrade
end

node.default['scale_datadog']['monitors']['postfix'] = {
  'init_config' => nil,
  'instances' => [{
    'directory' => '/var/spool/postfix',
    'queues' => ['incoming', 'active', 'deferred'],
  }],
}

node.default['scale_sudo']['users']['dd-agent'] =
  'ALL=(ALL) NOPASSWD:/usr/bin/find /var/spool/postfix/ -type f, ' +
  '/bin/find /var/spool/postfix/ -type f'

d = {}
if File.exists?('/etc/lists_secrets')
  File.read('/etc/lists_secrets').each_line do |line|
    k, v = line.strip.split(/\s*=\s*/)
    d[k.downcase] = v
  end
end

node.default['scale_phplist']['mysql_db'] = d['mysql_db']
node.default['scale_phplist']['mysql_user'] = d['mysql_user']
node.default['scale_phplist']['mysql_password'] = d['mysql_password']
node.default['scale_phplist']['mysql_host'] = d['mysql_host']
node.default['scale_phplist']['bounce_mailbox_host'] = d['bounce_mailbox_host']
node.default['scale_phplist']['bounce_mailbox_user'] = d['bounce_mailbox_user']
node.default['scale_phplist']['bounce_mailbox_password'] = 
  d['bounce_mailbox_password']

include_recipe 'fb_init::iptables_settings'

to_remove = %w{
  rpcbind
  abrt
}
package to_remove do
  action :remove
end

# 32-bit systemd doesn't belong here
package 'systemd-libs' do
  arch 'i686'
  action :remove
end
