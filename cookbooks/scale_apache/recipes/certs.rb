# in dev, we won't have a cert, so create one
if File.exist?('/etc/httpd/need_dev_keys')
  execute 'generate dev keys' do
    creates '/etc/httpd/apache.key'
    command 'openssl req -x509 -newkey rsa:2048 -keyout /etc/httpd/apache.key' +
      ' -out /etc/httpd/apache.crt -days 999 -nodes -subj ' +
      '"/O=scale/countryName=US/commonName=www.socallinuxexpo.org"'
  end
  return
end

include_recipe 'fb_letsencrypt'

%w{crt key}.each do |type|
  link "/etc/httpd/apache.#{type}" do
    to lazy {
      FB::LetsEncrypt.send(
        type.to_sym, node, node['scale_apache']['ssl_hostname']
      )
    }
  end
end
