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
    command 'openssl req -x509 -newkey rsa:2048 -keyout /etc/httpd/apache.key ' +
      '-out /etc/httpd/apache.crt -days 999 -nodes -subj ' +
      '"/O=scale/countryName=US/commonName=www.socallinuxexpo.org"'
  end
end
