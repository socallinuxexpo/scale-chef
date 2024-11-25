pkgs = []

pkgs << 'certbot' unless node.centos10?

# undeclared dependency in c7
pkgs << 'python-acme' if node.centos7?

unless pkgs.length.zero?
  package pkgs do
    action :upgrade
  end
end

if node.centos10?
  cachefile = "#{Chef::Config['file_cache_path']}/certbot-venv.tar.bz2"
  cookbook_file cachefile do
    owner 'root'
    group 'root'
    mode '0640'
  end

  archive_file cachefile do
    destination '/usr/local/certbot-venv'
    strip_components 1
  end
end

# Always run our renewal script
cookbook_file '/usr/local/sbin/renew_certs.sh' do
  owner 'root'
  group 'root'
  mode '0755'
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

