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
