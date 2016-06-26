#
# Cookbook Name:: scale_phplist
# Recipe:: default
#

pkgs = %w{
  httpd
  mod_ssl
  php
  php-mysql
}

package pkgs do
  action :upgrade
  notifies :restart, 'service[httpd]'
end

remote_file "#{Chef::Config['file_cache_path']}/phplist-3.2.5.tgz" do
  source "https://s3.amazonaws.com/scale-packages/phplist-3.2.5.tgz"
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

tarball_x "#{Chef::Config['file_cache_path']}/phplist-3.2.5.tgz" do
  destination '/usr/local/' # Will be created if missing
  owner 'root'
  group 'apache'
  umask 002 # Will be applied to perms in archive
  action :extract
end

template "/usr/local/phplist-3.2.5/public_html/lists/config/config.php" do
  owner 'root'
  group 'apache'
  mode '0640'
end

link '/var/www/html/lists' do
  to "/usr/local/phplist-3.2.5/public_html/lists"
end

service 'httpd' do
  action [:enable, :start]
end
