cookbook_file '/usr/local/sbin/chefctl.rb' do
  owner 'root'
  group 'root'
  mode '0755'
end

link '/usr/local/sbin/chefctl' do
  to '/usr/local/sbin/chefctl.rb'
end

cookbook_file '/etc/chefctl-config.rb' do
  owner 'root'
  group 'root'
  mode '0644'
end

cookbook_file '/etc/chef/chefctl_hooks.rb' do
  owner 'root'
  group 'root'
  mode '0644'
end
