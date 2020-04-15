#
# Cookbook Name:: scale_apache
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'scale_apache::common'
include_recipe 'fb_apache'

common_config = {
  'ServerName' => 'www.socallinuxexpo.org',
  'ServerAdmin' => 'webmaster@socallinuxexpo.org',
  'ServerAlias' => [
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
  'Alias' => [
    '/past /home/webroot/past',
    '/scale5x /home/webroot/scale5x',
    '/scale6x /home/webroot/scale6x',
    '/scale7x /home/webroot/scale7x',
    '/scale7x-audio /home/webroot/scale7x-audio',
    '/scale8x /home/webroot/scale8x',
    '/scale9x /home/webroot/scale9x',
    '/scale9x-media /home/webroot/scale9x-media',
    '/scale10x /home/webroot/scale10x',
    '/scale10x-supporting /home/webroot/scale10x-supporting',
    '/scale11x /home/webroot/scale11x',
    '/scale11x-supporting /home/webroot/scale11x-supporting',
    '/scale12x /home/webroot/scale12x',
    '/scale12x-supporting /home/webroot/scale12x-supporting',
    '/doc /usr/share/doc',
  ],
  'Location /server-status' => {
    'SetHandler' => 'server-status',
    'Order' => 'Deny,Allow',
    'Deny' => 'from all',
    'Allow' => 'from localhost',
  },
  'RewriteEngine' => 'On',
  'DocumentRoot' => '/home/drupal/scale-drupal/httpdocs',
  'Directory /' => {
    'Options' => 'FollowSymLinks',
    'AllowOverride' => 'None',
  },
  'Directory /home/drupal/scale-drupal/httpdocs' => {
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
}

rewrites = {
  'CFPs' => {
    'rule' => '^/(.*) https://www.socallinuxexpo.org/cfp/ [L,R,NE]',
    'conditions' => [
      '%{HTTP_HOST} ^cfp.socallinuxexpo.org [NC]'
    ],
  },
  'not our host' => {
     'rule' => '^/(.*) http://www.socallinuxexpo.org/$1 [L,R,NE]',
     'conditions' => [
       '%{REQUEST_URI} !^/server-status',
       '%{HTTP_HOST} !^www.socallinuxexpo.org [NC]',
       '%{HTTP_HOST} !^$',
     ],
  },
  'always ensure www' => {
    'rule' => '^ http%{ENV:protossl}://www.%{HTTP_HOST}%{REQUEST_URI} [L,R=301]',
    'conditions' => [
      '%{HTTP_HOST} .',
      '%{REQUEST_URI} !^/server-status',
      '%{HTTP_HOST} !^www\. [NC]',
    ],
  },
  'redirect / to current site' => {
    'rule' => '^/(.*) http://www.socallinuxexpo.org/scale/18x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/$',
    ],
  },
  'redirect scale18x short url to proper url' => {
    'rule' => '^/(.*) http://www.socallinuxexpo.org/scale/18x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale18x$',
    ],
  },
  'redirect scale17x short url to proper url' => {
    'rule' => '^/(.*) http://www.socallinuxexpo.org/scale/17x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale17x$',
    ],
  },
  'redirect scale16x short url to proper url' => {
    'rule' => '^/(.*) http://www.socallinuxexpo.org/scale/16x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale16x$',
    ],
  },
  'redirect scale15x short url to proper url' => {
    'rule' => '^/(.*) http://www.socallinuxexpo.org/scale/15x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale15x$',
    ],
  },
  'safety' => {
    'rule' => '^/safety http://www.socallinuxexpo.org/scale/15x/anti-harassment-policy [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/safety$',
    ],
  },
  'scale 14x' => {
    'rule' => '^/(.*) http://www.socallinuxexpo.org/scale/14x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale14x$',
    ],
  },
  'scale 14x 2' => {
    'rule' => '^/scale14x/(.*) http://www.socallinuxexpo.org/scale/14x/$1 [L,R=301,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale14x/',
    ],
  },
  'scale 13x' => {
    'rule' => '^/(.*) http://www.socallinuxexpo.org/scale/13x [L,R,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale13x$',
    ],
  },
  'scale 13x 2' => {
    'rule' => '^/scale13x/(.*) http://www.socallinuxexpo.org/scale/13x/$1 [L,R=301,NE]',
    'conditions' => [
      '%{REQUEST_URI} ^/scale13x/',
    ],
  },
}

node.default['fb_apache']['sites']['*:80'] = common_config
node.default['fb_apache']['sites']['*:80']['_rewrites'] = rewrites

{
  'cfp1' => '%{REQUEST_URI} ^/(user|cfp)$',
  'cfp2' => '%{REQUEST_URI} ^/scale/14x/(user|cfp)$',
  'cfp3' => '%{REQUEST_URI} ^/(user|cfp)/',
  'cfp4' => '%{REQUEST_URI} ^/scale/14x/(user|cfp)/',
}.each do |name, condition|
  node.default['fb_apache']['sites']['*:80']['_rewrites'][name] = {
    # yes these are supposed to be ssl
    'rule' => '^/(.*) https://www.socallinuxexpo.org/$1 [L,R,NE]',
    'conditions' => [condition],
  }
end

# munged for https
# note we don't just dup because dup doesn't deeply-copy enough
sslrewrites = {}
rewrites.each do |name, ruleset|
  sslrewrites[name] = {
    'rule' => rewrites[name]['rule'].sub(' http://', ' https://'),
    'conditions' => rewrites[name]['conditions'],
  }
end

node.default['fb_apache']['sites']['_default_:443'] = common_config
node.default['fb_apache']['sites']['_default_:443']['_rewrites'] = sslrewrites

# some SSL overrides
{
  'ErrorLog' => '/var/log/httpd/ssl_error.log',
  'CustomLog' => '/var/log/httpd/ssl_access.log combined',
  'SSLEngine' => 'on',
  'SSLProtocol' => 'all -SSLv2 -SSLv3',
  'SSLCipherSuite' => '"EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH EDH+aRSA !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS !RC4"',
  'SSLCertificateKeyFile' => '/etc/httpd/apache.key',
  'SSLCertificateFile' => '/etc/httpd/apache.crt',
  'SSLCertificateChainFile' => '/etc/httpd/intermediate.pem',
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
  php
  php-gd
  php-mysql
  php-pdo
  php-xml
  php-mbstring
  python2-boto
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
      "sourcecategory" => "http_web_access",
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
      "sourcecategory" => "http_web_access",
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
