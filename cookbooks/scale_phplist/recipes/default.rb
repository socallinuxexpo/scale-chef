#
# Cookbook Name:: scale_phplist
# Recipe:: default
#

# for PHP
node.default['fb_apache']['mpm'] = 'prefork'
pkgs = %w{}

%w{
  mysql_db
  mysql_user
  mysql_password
  mysql_host
  bounce_mailbox_host
  bounce_mailbox_user
  bounce_mailbox_password
}.each do |sec|
  next unless node['fb_init']['secrets'][sec]
  node.default['scale_phplist'][sec] = node['fb_init']['secrets'][sec]
end

if node.centos8?
  node.default['scale_phplist']['version'] = '3.5.2'
  pkgs += %w{
    php
    php-mysqlnd
    php-imap
  }

  node.default['fb_apache']['modules'] << 'php7'
  relpath = File.join(Chef::Config['file_cache_path'], 'remi-release-8.rpm')
  remote_file relpath do
    source 'https://rpms.remirepo.net/enterprise/remi-release-8.rpm'
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end

  package 'remi-release-8' do
    source relpath
    action :install
  end

  # for php-imap
  node.default['fb_dnf']['modules']['php'] = {
    'enable' => true,
    'stream' => 'remi-7.2',
  }
elsif node.centos9?
  # this whole thing is fraught with ordering issues.
  # 
  # You need a run with just the remi-release RPM setup
  #
  # Another run with the DNF modulues
  #
  # Then another run to setup the packages
  #
  # Then another run with the fb_apache stuff...

  # enable this first...
  relpath = File.join(Chef::Config['file_cache_path'], 'remi-release-9.rpm')
  remote_file relpath do
    source 'https://rpms.remirepo.net/enterprise/remi-release-9.rpm'
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end

  package 'remi-release-9' do
    source relpath
    action :install
  end

  # then this...
  node.default['fb_dnf']['modules']['php'] = {
    'enable' => true,
    'stream' => 'remi-8.2',
  }

  # then this...
  pkgs += %w{
    php
    php-mysqlnd
    php-imap
  }

  # then this...
  node.default['fb_apache']['modules_mapping']['php'] = 'libphp.so'
  node.default['fb_apache']['modules'] << 'php'
end

package pkgs do
  action :upgrade
  notifies :restart, 'service[apache]'
end

remote_file 'fetch phplist tarball' do
  not_if do
    File.directory?("/usr/local/phplist-#{node['scale_phplist']['version']}")
  end
  source lazy {
    "https://s3.amazonaws.com/scale-packages/phplist-#{node['scale_phplist']['version']}.tgz"
  }
  path lazy { 
    "#{Chef::Config['file_cache_path']}/phplist-#{node['scale_phplist']['version']}.tgz" 
  }
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

execute 'extract phplist tarball' do
  command lazy {
    "tar xf #{Chef::Config['file_cache_path']}/phplist-#{node['scale_phplist']['version']}.tgz -C /usr/local/ --owner=root --group=apache"
  }
  creates lazy { "/usr/local/phplist-#{node['scale_phplist']['version']}" }
end

template 'config.php' do
  path lazy { 
    "/usr/local/phplist-#{node['scale_phplist']['version']}/public_html/lists/config/config.php" 
  }
  owner 'root'
  group 'apache'
  mode '0640'
end

link '/var/www/html/lists' do
  to lazy {
    "/usr/local/phplist-#{node['scale_phplist']['version']}/public_html/lists" 
  }
end

cookbook_file '/usr/local/sbin/phplist_wrapper' do
  source 'phplist_wrapper.sh'
  owner 'root'
  group 'root'
  mode '0755'
end

# the queue will get process on it's own, but running this helps speed it up
# See:
# https://www.phplist.org/manual/books/phplist-manual/page/setting-up-your-cron
node.default['fb_cron']['jobs']['process_queue'] = {
  'time' => '*/5 * * * *',
  'command' => '/usr/local/sbin/phplist_wrapper -pprocessqueue &>/dev/null',
}

# same
node.default['fb_cron']['jobs']['process_bounces'] = {
  'time' => '0 3 * * *',
  'command' => '/usr/local/sbin/phplist_wrapper -pprocessbounces &>/dev/null',
}
