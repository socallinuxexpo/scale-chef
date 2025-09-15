name = 'register.socallinuxexpo.org'

node.default['scale_apache']['ssl_hostname'] = name

%w{crt key}.each do |type|
  link "/etc/httpd/apache.#{type}" do
    to FB::LetsEncrypt.send(type.to_sym, node, name)
  end
end

pkgs = %w{
  python3-mod_wsgi
  python3-mysqlclient
  python3-pip
}

package pkgs do
  action :upgrade
end

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

dynamic_dir = '/var/www/django'
execute 'install py reqs' do
  command "pip install -r #{dynamic_dir}/requirements.txt"
  action :nothing
end

# basic initialization
git dynamic_dir do
  not_if { ::File.exist?(dynamic_dir) }
  repository 'https://github.com/socallinuxexpo/scalereg.git'
  notifies :run, 'execute[install py reqs]', :immediately
end

template "#{dynamic_dir}/scalereg3/scalereg3/settings.py" do
  owner 'apache'
  group 'apache'
  mode '0640'
end

static_src = '/usr/local/lib/python3.12/site-packages/django/contrib' +
  '/admin/static'
static_dst = '/var/www/django_static'

# more init
execute 'initialize static data' do
  creates static_dst
  command "rsync -avz #{static_src}/ #{static_dst}/"
end

# enforce perms
[static_dst, dynamic_dir].each do |dir|
  directory dir do
    owner 'root'
    group 'root'
    mode '0755'
  end
end

include_recipe 'scale_apache::common'
include_recipe 'fb_apache'

node.default['fb_apache']['modules'] << 'wsgi'
node.default['fb_apache']['extra_configs']['WSGIPythonPath'] =
  '/var/www/django/scalereg3'

vhost_config = {
  'ServerName' => 'register.socallinuxexpo.org',
  'ServerAlias' => [
    'reg.socallinuxexpo.org',
  ],
  'ServerAdmin' => 'hostmaster@linuxfests.org',
  'DocumentRoot' => '/var/www/html',
  'DirectoryIndex' => 'index.html',
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
    'Require' => 'local',
  },
  'LogLevel' => 'warn',
  'WSGIScriptAlias' => [
    '/ /var/www/django/scalereg3/scalereg3/wsgi.py',
  ],
  'Alias' => [
    '/static /var/www/django_static',
    # because of the "/" alias, in order for letsencrypt/certbot to work
    # we need this alias
    '/.well-known /var/www/html/.well-known',
  ],
  'Directory /var/www/django/scalereg3/scalereg3' => {
    'Files wsgi.py' => {
      'Require' => 'all granted',
    },
  },
  'Directory /var/www/django_static' => {
    'Require' => 'all granted',
  },
}

node.default['fb_apache']['sites']['*:80'] = vhost_config
{
  'ErrorLog' => '/var/log/httpd/error.log',
  'CustomLog' => '/var/log/httpd/access.log combined',
  'RewriteEngine' => 'On',
}.each do |key, val|
  node.default['fb_apache']['sites']['*:80'][key] = val
end
node.default['fb_apache']['sites']['*:80']['_rewrites'] = {
  'force ssl' => {
    'rule' => '(.*) https://register.socallinuxexpo.org$1 [L,R]',
    'conditions' => [
      '%{HTTPS} off',
    ],
  },
}

node.default['fb_apache']['sites']['_default_:443'] = vhost_config
{
  'ErrorLog' => '/var/log/httpd/ssl_error.log',
  'CustomLog' => '/var/log/httpd/ssl_access.log combined',
  'SSLEngine' => 'on',
  'SSLCertificateKeyFile' => '/etc/httpd/apache.key',
  'SSLCertificateFile' => '/etc/httpd/apache.crt',
  'SSLProtocol' => 'all -SSLv2 -SSLv3',
  'FilesMatch "\.(cgi|shtml)$"' => {
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
  node.default['fb_apache']['sites']['_default_:443'][key] = val
end
