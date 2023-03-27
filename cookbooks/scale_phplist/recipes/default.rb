#
# Cookbook Name:: scale_phplist
# Recipe:: default
#

pkgs = %w{
  php
  php-mysql
  php-imap
}

pkgs << 'phplist' unless node.centos7?

package pkgs do
  action :upgrade
  notifies :restart, 'service[apache]'
end

if node.centos7?
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

  link '/var/www/html/lists' do
    to lazy {
      "/usr/local/phplist-#{node['scale_phplist']['version']}/public_html/lists" 
    }
  end
end


template 'config.php' do
  path lazy { 
    if node.centos7?
      "/usr/local/phplist-#{node['scale_phplist']['version']}/public_html/lists/config/config.php" 
    else
      '/var/www/html/lists/config/config.php'
    end
  }
  owner 'root'
  group 'apache'
  mode '0640'
end
