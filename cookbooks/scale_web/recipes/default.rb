#
# Cookbook Name:: scale_web
# Recipe:: default
#
# Copyright 2016, SCALE
#

drupal10 = (node['hostname'] == 'scale-web-centos10')
drupal10_staging = (node['hostname'] == 'scale-web-centos10-staging')

if drupal10
  server_name = 'www.socallinuxexpo.org'
  node.default['scale_apache']['ssl_hostname'] = server_name
  docroot = '/home/drupal/scale-drupal/web'
elsif drupal10_staging
  server_name = 'www-staging.socallinuxexpo.org'
  node.default['scale_apache']['ssl_hostname'] = server_name
  docroot = '/home/drupal/scale-drupal/web'
else
  server_name = 'www.socallinuxexpo.org'
  docroot = '/home/drupal/scale-drupal/httpdocs'
end

include_recipe 'scale_apache::common'
include_recipe 'fb_apache'

node.default['fb_apache']['mpm'] = 'prefork'

node.default['fb_apache']['modules'] << 'fcgid'
node.default['fb_apache']['modules'] << 'proxy'
node.default['fb_apache']['modules'] << 'proxy_fcgi'

cookbook_file '/etc/php.ini' do
  owner 'root'
  group 'root'
  mode '0644'
end

common_config = {
  'ServerName' => server_name,
  'ServerAdmin' => 'webmaster@socallinuxexpo.org',
  'ServerAlias' => drupal10 ? [server_name] : [
    'socallinuxexpo.org',
    'socallinuxexpo.com',
    'www.socallinuxexpo.com',
    'www.socallinuxexpo.net',
    'southerncalifornialinuxexpo.com',
    'southerncalifornialinuxexpo.org',
    'southerncalifornialinuxexpo.net',
    'www.southerncalifornialinuxexpo.com',
    'www.southerncalifornialinuxexpo.org',
    'www.southerncalifornialinuxexpo.net',
  ],
  # Not used by much, because of our http->https redirect,
  # but needed for the LetsEncrypt tokens
  'DocumentRoot' => docroot,
  "Directory #{docroot}/.well-known" => {
    'Allow' => 'from all',
    'Require' => 'all granted',
  },
  'Location /server-status' => {
    'SetHandler' => 'server-status',
    'Require' => 'local',
  },
}

node.default['fb_apache']['sites']['*:80'] = common_config.merge({
  'RedirectMatch permanent ^/(?!server-status|.well-known)' =>
    "https://#{server_name}/",
})

node.default['fb_apache']['extra_configs']['MaxConnectionsPerChild'] = 50
node.default['fb_apache']['extra_configs']['MaxRequestWorkers'] = 50

# With event, increase this directive if the process number defined by your
# MaxRequestWorkers and ThreadsPerChild settings, plus the number of gracefully
# shutting down processes, is more than 16 server processes (default).
#
# Our MaxRequestWorkers is 50. We don't define ThreadsPerChild which defaults
# to 25. So if I read that correctly (and I haven't tuned Apache for a living
# in a looonnnggg time), we want something like 50+25=75 plus some more for
# shutting down processes, so like... 80?
node.default['fb_apache']['extra_configs']['ServerLimit'] = 80

# see if this helps with hung processes...
node.default['fb_apache']['extra_configs']['KeepAlive'] = 'off'

base_config = common_config.merge({
  'Alias' => [
    '/past /home/webroot/past',
    '/scale5x /home/webroot/scale5x',
    '/scale6x /home/webroot/scale6x',
    '/scale7x /home/webroot/scale7x',
    '/scale7x-audio /home/webroot/scale7x-audio',
    '/scale8x /home/webroot/scale8x',
    '/scale9x /hoce/webroot/scale9x',
    '/scale9x-media /home/webroot/scale9x-media',
    '/scale10x /home/webroot/scale10x',
    '/scale10x-supporting /home/webroot/scale10x-supporting',
    '/scale11x /home/webroot/scale11x',
    '/scale11x-supporting /home/webroot/scale11x-supporting',
    '/scale12x /home/webroot/scale12x',
    '/scale12x-supporting /home/webroot/scale12x-supporting',
    '/scale/13x /home/webroot/scale/13x',
    '/scale/14x /home/webroot/scale/14x',
    '/scale/15x /home/webroot/scale/15x',
    '/scale/16x /home/webroot/scale/16x',
    '/scale/17x /home/webroot/scale/17x',
    '/scale/18x /home/webroot/scale/18x',
    '/scale/19x /home/webroot/scale/19x',
    '/scale/20x /home/webroot/scale/20x',
    '/scale/21x /home/webroot/scale/21x',
    '/scale/22x /home/webroot/scale/22x',
    '/doc /usr/share/doc',
  ],
  'RewriteEngine' => 'On',
  'DocumentRoot' => docroot,
  'Directory /' => {
    'Options' => 'FollowSymLinks',
    'AllowOverride' => 'None',
  },
  "Directory #{docroot}" => {
    'Options' => 'Indexes FollowSymLinks MultiViews',
    'AllowOverride' => 'all',
    'Order' => 'allow,deny',
    'Allow' => 'from all',
    'Require' => 'all granted',
  },
  'Directory /home/webroot' => {
    'Options' => 'Indexes FollowSymLinks MultiViews',
    'AllowOverride' => 'all',
    'Order' => 'allow,deny',
    'Allow' => 'from all',
    'Require' => 'all granted',
  },
  'ScriptAlias' => '/cgi-bin/ /usr/lib/cgi-bin/',
  'Directory /usr/lib/cgi-bin' => {
    'AllowOverride' => 'None',
    'Options' => '+ExecCGI -MultiViews +SymLinksIfOwnerMatch',
    'Order' => 'allow,deny',
    'Allow' => 'from all',
  },
  'ErrorLog' => '/var/log/httpd/error.log',
  'LogLevel' => 'warn',
  'CustomLog' => '/var/log/httpd/access.log combined',
  'Directory /usr/share/doc/' => {
    'Options' => 'Indexes MultiViews FollowSymLinks',
    'AllowOverride' => 'None',
    'Order' => 'deny,allow',
    'Deny' => 'from all',
    'Allow' => 'from 127.0.0.0/255.0.0.0 ::1/128',
  },
})

rewrites = {
  "CFPs" => {
    "rule" => "^/(.*) https://#{server_name}/cfp/ [L,R,NE]",
    "conditions" => [
      "%{HTTP_HOST} ^cfp.socallinuxexpo.org [NC]"
    ],
  },
  "not our host" => {
     "rule" => "^/(.*) https://#{server_name}/$1 [L,R,NE]",
     "conditions" => [
       "%{REQUEST_URI} !^/server-status",
       "%{HTTP_HOST} !^#{server_name} [NC]",
       "%{HTTP_HOST} !^$",
     ],
  },
  "always ensure www" => {
    "rule" => "^ https://#{server_name}%{REQUEST_URI} [L,R=301]",
    "conditions" => [
      "%{HTTP_HOST} .",
      "%{REQUEST_URI} !^/server-status",
      "%{HTTP_HOST} !^#{server_name} [NC]",
    ],
  },
  "redirect / to current site" => {
    "rule" => "^/(.*) https://#{server_name}/scale/23x [L,R,NE]",
    "conditions" => [
      "%{REQUEST_URI} ^/$",
    ],
  },
  "year short url" => {
    "rule" => "^/scale(1[3-9]|[2-9][0-9])x$ https://#{server_name}/scale/$1x [L,R,NE]",
      "conditions" => [
      "%{REQUEST_URI} ^/scale(1[3-9]|[2-9][0-9])x$",
    ],
  },
  "year deep path" => {
    "rule" => "^/scale(1[3-9]|[2-9][0-9])x/(.*)$ https://#{server_name}/scale/$1x/$2 [L,R=301,NE]",
    "conditions" => [
      "%{REQUEST_URI} ^/scale(1[3-9]|[2-9][0-9])x/",
    ],
  },
  "scale4x short url" => {
    "rule" => "^/scale4x$ https://#{server_name}/past/2006/ [L,R,NE]",
    "conditions" => [
      "%{REQUEST_URI} ^/scale4x$",
    ],
  },
  "scale4x deep path" => {
    "rule" => "^/scale4x/(.*)$ https://#{server_name}/past/2006/$1 [L,R=301,NE]",
    "conditions" => [
      "%{REQUEST_URI} ^/scale4x/",
    ],
  },
  "scale3x short url" => {
    "rule" => "^/scale3x$ https://#{server_name}/past/2005/ [L,R,NE]",
    "conditions" => [
      "%{REQUEST_URI} ^/scale3x$",
    ],
  },
  "scale3x deep path" => {
    "rule" => "^/scale3x/(.*)$ https://#{server_name}/past/2005/$1 [L,R=301,NE]",
    "conditions" => [
      "%{REQUEST_URI} ^/scale3x/",
    ],
  },
  
  "scale2x short url" => {
    "rule" => "^/scale2x$ https://#{server_name}/past/2003/ [L,R,NE]",
    "conditions" => [
      "%{REQUEST_URI} ^/scale2x$",
    ],
  },
  "redirect scale2x deep path to past" => {
    "rule" => "^/scale2x/(.*)$ https://#{server_name}/past/2003/$1 [L,R=301,NE]",
    "conditions" => [
      "%{REQUEST_URI} ^/scale2x/",
    ],
  },
  
  "redirect scale1x short url to past" => {
    "rule" => "^/scale1x$ https://#{server_name}/past/2002/ [L,R,NE]",
    "conditions" => [
      "%{REQUEST_URI} ^/scale1x$",
    ],
  },
  "redirect scale1x deep path to past" => {
    "rule" => "^/scale1x/(.*)$ https://#{server_name}/past/2002/$1 [L,R=301,NE]",
    "conditions" => [
      "%{REQUEST_URI} ^/scale1x/",
    ],
  },
}

if drupal10_staging
  rewrites['robots.txt'] = {
    'rule' => '^/robots\.txt$ /home/webroot/robots-staging.txt [L]',
    'conditions' => [],
  }
end

node.default['fb_apache']['sites']['_default_:443'] = base_config
node.default['fb_apache']['sites']['_default_:443']['_rewrites'] = rewrites

# some SSL specifics
{
  'ErrorLog' => '/var/log/httpd/ssl_error.log',
  'CustomLog' => '/var/log/httpd/ssl_access.log combined',
  'SSLEngine' => 'on',
  'SSLProtocol' => 'all -SSLv2 -SSLv3',
  'SSLCipherSuite' => '"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH EDH+aRSA !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS !RC4"',
  'SSLCertificateKeyFile' => '/etc/httpd/apache.key',
  'SSLCertificateFile' => '/etc/httpd/apache.crt',
  'FilesMatch \.(cgi|shtml|phtml|php)$' => {
    'SSLOptions' => '+StdEnvVars',
  },
  'Directory /usr/lib/cgi-bin' => {
    'SSLOptions' => '+StdEnvVars'
  },
  'BrowserMatch' => [
    '"MSIE [2-6]" nokeepalive ssl-unclean-shutdown downgrade-1.0' +
      'force-response-1.0',
    '"MSIE [17-9]" ssl-unclean-shutdown',
  ],
}.each do |key, val|
  node.default['fb_apache']['sites']['_default_:443'][key] = val
end

node.default['fb_dnf']['config']['main']['exclude'] = 'php8.4*'
pkgs = %w{
  git
  python3-boto3
  php
  php-gd
  php-pdo
  php-xml
  php-mbstring
  php-mysqlnd
  php-fpm
  php-json
  php-soap
  composer
}

package pkgs do
  action :upgrade
  notifies :restart, 'service[apache]'
end

directory '/home/drupal' do
  owner 'root'
  group 'root'
  mode '0755'
end

include_recipe 'scale_drupal'

node.default['fb_systemd']['tmpfiles']['/tmp'] = {
  'type' => 'D',
  'mode' => '1777',
  'uid' => 'root',
  'gid' => 'root',
  'age' => '72h',
}

node.default['scale_datadog']['monitors']['apache'] = {
  "init_config" => nil,
  "instances" => [
    {
      "apache_status_url" => "http://localhost/server-status?auto"
    },
  ],
  "logs" => [
    {
      "type" => "file",
      "path" => "/var/log/httpd/access.log",
      "source" => "apache",
      "sourcecategory" => "http_web_access",
      "service" => "apache"
    },
    {
      "type" => "file",
      "path" => "/var/log/httpd/ssl_access.log",
      "source" => "apache",
      "sourcecategory" => "http_web_access",
      "service" => "apache"
    },
    {
      "type" => "file",
      "path" => "/var/log/httpd/error.log",
      "source" => "apache",
      "sourcecategory" => "http_web_error",
      "service" => "apache"
    },
    {
      "type" => "file",
      "path" => "/var/log/httpd/error_log",
      "source" => "apache",
      "sourcecategory" => "http_web_error",
      "service" => "apache"
    },
    {
      "type" => "file",
      "path" => "/var/log/httpd/access_log",
      "source" => "apache",
      "sourcecategory" => "http_web_access",
      "service" => "apache"
    },
    {
      "type" => "file",
      "path" => "/var/log/httpd/ssl_access_log",
      "source" => "apache",
      "sourcecategory" => "http_web_access",
      "service" => "apache"
    },
    {
      "type" => "file",
      "path" => "/var/log/httpd/ssl_error_log",
      "source" => "apache",
      "sourcecategory" => "http_web_error",
      "service" => "apache"
    },
    {
      "type" => "file",
      "path" => "/var/log/httpd/ssl_error.log",
      "source" => "apache",
      "sourcecategory" => "http_web_error",
      "service" => "apache"
    },
  ]
}

node.default['scale_datadog']['monitors']['dns_check'] = {
   "init_config" => {
     "default_timeout" => 4
   },
   "instances" => [
     {
       "hostname" => "www.socallinuxexpo.org",
       "nameserver" => "8.8.8.8",
       "timeout" => 8
     },
   ],
}

node.default['scale_datadog']['monitors']['linux_proc_extras'] = {
  "init_config" => nil,
  "instances" => [
    {
      "tags" => []
    },
  ],
}
