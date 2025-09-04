#
# Cookbook Name:: scale_web
# Recipe:: default
#
# Copyright 2016, SCALE
#

drupal10 = (node['hostname'] == 'scale-web-centos10-newsite')

if drupal10
  server_name = 'www-test.socallinuxexpo.org'
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

# for old-web, with old-drupal, we need remi for old-php
if node['hostname'] == 'scale-web-centos10'
  relpath = File.join(Chef::Config['file_cache_path'], 'remi-release-10.rpm')
  remote_file relpath do
    source 'https://rpms.remirepo.net/enterprise/remi-release-10.rpm'
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end

  package 'remi-release-10' do
    source relpath
    action :install
  end

  node.default['fb_dnf']['modules']['php'] = {
    'enable' => true,
    'stream' => 'remi-8.0',
  }
end

# we haven't used this in a bit, fortunately, but keeping it around
# for easy re-enabling if we ever do.
#if node['hostname'] == 'scale-web2'
#  apache_debug_log = '/var/log/apache_status.log'
#  node.default['fb_cron']['jobs']['ugly_restarts'] = {
#    # 2x a day
#    'time' => '02 */2 * * *',
#    'command' => "date >> #{apache_debug_log}; ps -eL " +
#      '-o user,pid,lwp,nlwp,\%cpu,\%mem,vsz,rss,tty,stat,start,time,cmd ' +
#      "| grep ^apache >> #{apache_debug_log}; " +
#      '/usr/bin/systemctl restart httpd',
#  }
#  node.default['fb_logrotate']['configs']['apache_status'] = {
#    'files' => [apache_debug_log],
#  }
#end

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
    'https://www.socallinuxexpo.org/',
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
    '/scale/23x /home/webroot/scale23x-static',
    '/scale/13x /home/webroot/scale/13x',

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
  'CFPs' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/cfp/ [L,R,NE]',
    'conditions' => [
      '%{HTTP_HOST} ^cfp.socallinuxexpo.org [NC]'
    ],
  },
  'not our host' => {
     'rule' => '^/(.*) https://www.socallinuxexpo.org/$1 [L,R,NE]',
     'conditions' => [
       '%{REQUEST_URI} !^/server-status',
       '%{HTTP_HOST} !^www.socallinuxexpo.org [NC]',
       '%{HTTP_HOST} !^$',
     ],
  },
  'always ensure www' => {
    'rule' => '^ https://www.%{HTTP_HOST}%{REQUEST_URI} [L,R=301]',
    'conditions' => [
      '%{HTTP_HOST} .',
      '%{REQUEST_URI} !^/server-status',
      '%{HTTP_HOST} !^www\. [NC]',
    ],
  },
  'redirect / to current site' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/scale/22x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/$',
    ],
  },
  'redirect scale23x short url to proper url' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/scale/23x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale23x$',
    ],
  },
  'scale 23x 2' => {
    'rule' => '^/scale23x/(.*) https://www.socallinuxexpo.org/scale/23x/$1 [L,R=301,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale23x/',
    ],
  },
  'redirect scale22x short url to proper url' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/scale/22x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale22x$',
    ],
  },
  'scale 22x 2' => {
    'rule' => '^/scale22x/(.*) https://www.socallinuxexpo.org/scale/22x/$1 [L,R=301,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale22x/',
    ],
  },
  'redirect scale21x short url to proper url' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/scale/21x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale21x$',
    ],
  },
  'scale 21x 2' => {
    'rule' => '^/scale21x/(.*) https://www.socallinuxexpo.org/scale/21x/$1 [L,R=301,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale21x/',
    ],
  },
  'redirect scale20x short url to proper url' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/scale/20x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale20x$',
    ],
  },
  'scale 20x 2' => {
    'rule' => '^/scale20x/(.*) https://www.socallinuxexpo.org/scale/20x/$1 [L,R=301,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale20x/',
    ],
  },
  'redirect scale19x short url to proper url' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/scale/19x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale19x$',
    ],
  },
  'scale 19x 2' => {
    'rule' => '^/scale19x/(.*) https://www.socallinuxexpo.org/scale/19x/$1 [L,R=301,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale19x/',
    ],
  },
  'redirect scale18x short url to proper url' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/scale/18x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale18x$',
    ],
  },
  'scale 18x 2' => {
    'rule' => '^/scale18x/(.*) https://www.socallinuxexpo.org/scale/18x/$1 [L,R=301,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale18x/',
    ],
  },
  'redirect scale17x short url to proper url' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/scale/17x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale17x$',
    ],
  },
  'scale 17x 2' => {
    'rule' => '^/scale17x/(.*) https://www.socallinuxexpo.org/scale/17x/$1 [L,R=301,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale17x/',
    ],
  },
  'redirect scale16x short url to proper url' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/scale/16x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale16x$',
    ],
  },
  'scale 16x 2' => {
    'rule' => '^/scale16x/(.*) https://www.socallinuxexpo.org/scale/16x/$1 [L,R=301,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale16x/',
    ],
  },
  'redirect scale15x short url to proper url' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/scale/15x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale15x$',
    ],
  },
  'scale 15x 2' => {
    'rule' => '^/scale15x/(.*) https://www.socallinuxexpo.org/scale/15x/$1 [L,R=301,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale15x/',
    ],
  },
  'scale 14x' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/scale/14x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale14x$',
    ],
  },
  'scale 14x 2' => {
    'rule' => '^/scale14x/(.*) https://www.socallinuxexpo.org/scale/14x/$1 [L,R=301,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale14x/',
    ],
  },
  'scale 13x' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/scale/13x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale13x$',
    ],
  },
  'scale 13x 2' => {
    'rule' => '^/scale13x/(.*) https://www.socallinuxexpo.org/scale/13x/$1 [L,R=301,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale13x/',
    ],
  },
}

# for testing, we need to nuke these
if drupal10
  [
    'redirect / to current site',
    'not our host',
    'always ensure www',
  ].each do |redir|
    rewrites.delete(redir)
  end
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
