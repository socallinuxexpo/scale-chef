#
# Cookbook Name:: scale_phplist
# Recipe:: default
#

directory '/var/www' do
  owner 'root'
  group 'root'
  mode '0755'
end

directory '/var/www/html' do
  owner 'root'
  group 'root'
  mode '0755'
end

include_recipe 'scale_apache::common'
include_recipe 'fb_apache'

vhost_config = {
  'ServerName' => 'lists.socallinuxexpo.org',
  'ServerAdmin' => 'listmaster@linuxfests.org',
  'DocumentRoot' => '/var/www/html',
  'DirectoryIndex' => 'index.php index.html',
  'Directory /' => {
    'Options' => 'FollowSymLinks',
    'AllowOverride' => 'None',
  },
  'Directory /var/www/html' => {
    'Options' => 'Indexes FollowSymLinks MultiViews',
    'AllowOverride' => 'None',
    'Order' => 'allow,deny',
    'Allow' => 'from all',
    'Require' => 'all granted',
  },
  'Location /server-status' => {
    'SetHandler' => 'server-status',
    'Order' => 'Deny,Allow',
    'Deny' => 'from all',
    'Allow' => 'from localhost',
  },
  'LogLevel' => 'warn',
}

node.default['fb_apache']['sites']['*:80'] = vhost_config
{
  'ErrorLog' => '/var/log/httpd/error.log',
  'CustomLog' => '/var/log/httpd/access.log combined',
}.each do |key, val|
  node.default['fb_apache']['sites']['*:80'][key] = val
end
{
  'ErrorLog' => '/var/log/httpd/ssl_error.log',
  'CustomLog' => '/var/log/httpd/ssl_access.log combined',
  'SSLEngine' => 'on',
  'SSLCertificateFile' => '/etc/httpd/apache.pem',
  'SSLCertificateChainFile' => '/etc/httpd/sf_bundle.crt',
  'FilesMatch "\.(cgi|shtml|phtml|php)$"' => {
    'SSLOptions' => '+StdEnvVars',
  },
  'Directory /var/www/cgi-bin' => {
    'SSLOptions' => '+StdEnvVars',
  },
  'BrowserMatch "MSIE [2-6]"' => 
    'nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0',
  # MSIE 7 and newer should be able to use keepalive
  'BrowserMatch "MSIE [17-9]"' => 'ssl-unclean-shutdown',
}.each do |key, val|
  node.default['fb_apache']['sites']['_default_:443'] = vhost_config
end
