# vim:shiftwidth=2:expandtab

if node.centos7?
  epel_pkg = 'epel-release-7-14.noarch.rpm'

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
  # On CentOS9+ the EPEL repo depends on the CRB repo
  execute 'enable crb' do
    only_if { node.centos_min_version?(9) }
    not_if "dnf repolist | grep crb"
    command "dnf config-manager --set-enabled crb"
  end

  package 'epel-release' do
    action :upgrade
  end
end
