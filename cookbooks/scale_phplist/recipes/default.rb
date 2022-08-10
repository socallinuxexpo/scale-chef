#
# Cookbook Name:: scale_phplist
# Recipe:: default
#

pkgs = %w{
  php
  php-mysql
  php-imap
  phplist
}

package pkgs do
  action :upgrade
  notifies :restart, 'service[apache]'
end

template '/usr/share/phplist/public_html/lists/config/config.php' do
  owner 'root'
  group 'apache'
  mode '0640'
end

# migrate from old tarball install
link '/var/www/html/lists' do
  only_if { File.symlink?('/var/www/html/lists') }
  action :delete
end

execute 'migrate lists' do
  only_if do
    File.directory?(
      "/usr/local/phplist-#{node['scale_phplist']['version']}/public_html/lists"
    ) &&
    ! File.directory?('/var/www/html/lists')
  end
  command lazy {
    old =
      "/usr/local/phplist-#{node['scale_phplist']['version']}/public_html/list"
    new = '/var/www/html/lists'
    "mv #{old} #{new}"
  }
end
