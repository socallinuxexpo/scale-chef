# vim:shiftwidth=2:expandtab

if node.centos7?
  epel_pkg = 'epel-release-7-12.noarch.rpm'

  remote_file "#{Chef::Config['file_cache_path']}/#{epel_pkg}" do
    not_if { File.exists?('/etc/yum.repos.d/epel.repo') }
    source "https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/#{epel_pkg}"
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end

  package 'epel-release' do
    not_if { File.exists?('/etc/yum.repos.d/epel.repo') }
    source "#{Chef::Config['file_cache_path']}/#{epel_pkg}"
  end
else
  package 'epel-release' do
    action :upgrade
  end
end
