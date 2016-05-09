# This is where you set your own stuff...

node.default['scale_chef_client']['cookbook_dirs'] = [
  '/var/chef/repo/scale-chef/cookbooks',
  '/var/chef/repo/chef-cookbooks/cookbooks',
]
node.default['scale_chef_client']['role_dir'] =
  '/var/chef/repo/scale-chef/roles'
