# vim:shiftwidth=2:expandtab

remote_file "#{Chef::Config['file_cache_path']}/epel-release-7-8.noarch.rpm" do
  not_if { File.exists?('/etc/yum.repos.d/epel.repo') }
  source 'http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-8.noarch.rpm'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

package 'epel-release' do
  not_if { File.exists?('/etc/yum.repos.d/epel.repo') }
  source "#{Chef::Config['file_cache_path']}/epel-release-7-8.noarch.rpm"
end

