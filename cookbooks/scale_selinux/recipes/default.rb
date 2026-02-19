# vim:shiftwidth=2:expandtab

template '/etc/sysconfig/selinux' do
  source 'selinux.erb'
  owner 'root'
  group 'root'
  mode '0644'
end

current_state = File.read('/sys/fs/selinux/enforce').to_i

execute 'disable selinux' do
  only_if do
    %w{disabled permissive}.include?(node['scale_selinux']['state']) &&
      current_state == 1
  end
  command 'setenforce 0'
end

execute 'enable selinux' do
  only_if do
    node['scale_selinux']['state'] == 'enforcing' &&
      current_state == 0
  end
  command 'setenforce 1'
end
