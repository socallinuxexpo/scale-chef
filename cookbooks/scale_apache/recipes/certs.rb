pkgs = []

pkgs << 'certbot' unless node.centos10?

# undeclared dependency in c7
pkgs << 'python-acme' if node.centos7?

unless pkgs.length.zero?
  package pkgs do
    action :upgrade
  end
end

# Note, web is c10 only now, but if we have to bring back
# c9 for any reason, we'll need to bring back renew_certs.sh
# unless we've moved to fb_letsencrypt by then
if node.centos10?
  include_recipe 'scale_certbot_hack'
end

node.default['fb_cron']['jobs']['renew_certs'] = {
  'command' => '/usr/local/sbin/renew_certs.sh',
  'time' => '1 1 * * *',
}

# in dev, we won't have a cert, so create one
if File.exist?('/etc/httpd/need_dev_keys')
  execute 'generate dev keys' do
    creates '/etc/httpd/apache.key'
    command 'openssl req -x509 -newkey rsa:2048 -keyout /etc/httpd/apache.key' +
      ' -out /etc/httpd/apache.crt -days 999 -nodes -subj ' +
      '"/O=scale/countryName=US/commonName=www.socallinuxexpo.org"'
  end
else
  {
    'apache.key' => 'privkey.pem',
    'apache.crt' => 'cert.pem',
    'intermediate.pem' => 'chain.pem',
  }.each do |sslfile, path|
    link "/etc/httpd/#{sslfile}" do
      to lazy {
        host = node['scale_apache']['ssl_hostname']
        "/etc/letsencrypt/live/#{host}/#{path}"
      }
    end
  end
end

