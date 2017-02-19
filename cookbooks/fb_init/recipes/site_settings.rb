# This is where you set your own stuff...

node.default['scale_chef_client']['cookbook_dirs'] = [
  '/var/chef/repo/scale-chef/cookbooks',
  '/var/chef/repo/chef-cookbooks/cookbooks',
]
node.default['scale_chef_client']['role_dir'] =
  '/var/chef/repo/scale-chef/roles'

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
    node.default['scale_datadog']['config']['application_key'] = d['application_key']
  end
  if d['api_key']
    node.default['scale_datadog']['config']['api_key'] = d['api_key']
  end
end

{
  'decode' => 'root',
  'abuse' => 'postmaster',
  'spam' => 'postmaster',
  'root' => 'root@socallinuxexpo.org',
  'scale-voicemail' => 'scale-chairs',
}.each do |src, dst|
  node.default['scale_postfix']['aliases'][src] = dst
end

node.default['scale_datadog']['monitors']['postfix'] = {
  'init_config' => nil,
  'instances' => [{
    'directory' => '/var/spool/postfix',
    'queues' => ['incoming', 'active', 'deferred'],
  }],
}

node.default['scale_sudo']['users']['dd-agent'] =
  'ALL=(ALL) NOPASSWD:/usr/bin/find /var/spool/postfix/ -type f, /bin/find /var/spool/postfix/ -type f'

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

package 'abrt' do
  action :remove
end
