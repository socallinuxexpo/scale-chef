node.default['fb_postfix']['main.cf']['transport_maps'] =
  'hash:/var/lib/mailman3/data/postfix_lmtp'
node.default['fb_postfix']['main.cf']['local_recipient_maps'] <<
  ',hash:/var/lib/mailman3/data/postfix_lmtp'
node.default['fb_postfix']['main.cf']['relay_domains'] <<
  ',hash:/var/lib/mailman3/data/postfix_domains'

pkgs = [
  'mailman3',
  # webui
  'hyperkitty',
  # admin ui
  'postorius',
  # glue between hyperkitty and postorius
  'python3-mailman-web',
  # new emails into archive
  'python-mailman-hyperkitty',
  # xapian search backend
  'python3-xapian-haystack',
  # for xapian, bad deps
  'python3-filelock',
  # uwsgi
  'uwsgi',
  'uwsgi-logger-file',
  'uwsgi-plugin-python3',
  'python3-mysqlclient',
  'mysql',
  'sassc',
  'procmail',
  's-nail',
]

package pkgs do
  action :upgrade
  notifies :restart, 'service[apache]'
  notifies :restart, 'service[mailman]'
end

include_recipe 'scale_apache::simple'

node.default['fb_apache']['modules'] += ['proxy', 'proxy_http']
node.default['scale_apache']['ssl_hostname'] = 'lists.socallinuxexpo.org'
staticdir = '/var/www/html/static'
{
  'ServerName' => 'lists.socallinuxexpo.org',
  'ServerAlias' => [
    'lists2.socallinuxexpo.org',
    'lists.socallinuxexpo.net',
    'lists.socallinuxexpo.com',
    'lists.linuxfests.org',
    'lists.linuxfests.net',
    'lists.linuxfests.com',
  ],
  'Alias /static' => staticdir,
  "Directory #{staticdir}" => {
    'Require' => 'all granted',
    'Options' => 'FollowSymlinks',
  },
  'RequestHeader unset X-Forwarded-Proto' => '',
  'RequestHeader set X-Forwarded-Proto' => 'https',
  'ProxyPreserveHost' => 'On',
  'ProxyPass /mailman3' => 'http://127.0.0.1:8000/mailman3',
  'ProxyPass /archives' => 'http://127.0.0.1:8000/archives',
  'ProxyPass /accounts' => 'http://127.0.0.1:8000/accounts',
  'ProxyPass /admin' => 'http://127.0.0.1:8000/admin',
  'ProxyPass /user-profile' => 'http://127.0.0.1:8000/user-profile',
}.each do |key, val|
  node.default['fb_apache']['sites']['_default_:443'][key] = val
end

directory staticdir do
  owner 'root'
  group 'root'
  mode '0755'
end

Dir.glob(
  "/usr/lib/python3.9/site-packages/postorius/static/*"
) + %w{
  /usr/lib/python3.9/site-packages/django_mailman3/static/django-mailman3
  /usr/lib/python3.9/site-packages/hyperkitty/static/hyperkitty
  /usr/lib/python3.9/site-packages/django/contrib/admin/static/admin
}.each do |dir|
  base = File.basename(dir)
  link "#{staticdir}/#{base}" do
    to dir
  end
end

template '/etc/mailman.cfg' do
  source 'mailman3.cfg.erb'
  owner 'mailman'
  group 'mailman'
  mode '0640'
  notifies :restart, 'service[mailman]'
end

template '/etc/mailman3/uwsgi.ini' do
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, 'service[mailman]'
  notifies :restart, 'service[mailmanweb]'
end

template '/etc/mailman3/settings.py' do
  source 'mailman3-settings.py.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables({
    :staticdir => staticdir,
  })
  notifies :restart, 'service[mailman]'
  notifies :restart, 'service[mailmanweb]'
end

template '/etc/mailman3.d/hyperkitty.cfg' do
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, 'service[mailman]'
  notifies :restart, 'service[mailmanweb]'
end

cookbook_file '/etc/systemd/system/mailmanweb.service' do
  owner 'root'
  group 'root'
  mode '0644'
  notifies :reload, 'fb_systemd_reload[system instance]', :immediately
end

service 'mailmanweb' do
  action [:enable, :start]
end

file '/etc/cron.d/mailman3' do
  action :delete
end

node.default['fb_cron']['jobs']['mailman3-minutely'] = {
  'time' => '* * * * *',
  'command' => '/usr/bin/mailman-web runjobs minutely',
  'user' => 'mailman',
}

node.default['fb_cron']['jobs']['mailman3-quarter_hourly'] = {
  'time' => '0,15,30,45 * * * *',
  'command' => '/usr/bin/mailman-web runjobs quarter_hourly',
  'user' => 'mailman',
}

%w{hourly daily weekly monthly yearly}.each do |job|
  node.default['fb_cron']['jobs']["mailman3-#{job}"] = {
    'time' => "@#{job}",
    'command' => "/usr/bin/mailman-web runjobs #{job}",
    'user' => 'mailman',
  }
end

cookbook_file '/var/www/html/index.html' do
  source 'index-mailman3.html'
  owner 'root'
  group 'root'
  mode '0644'
end
