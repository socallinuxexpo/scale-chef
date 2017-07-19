execute 'generate dev keys' do
  creates '/etc/httpd/apache.key'
  command 'openssl req -x509 -newkey rsa:2048 -keyout /etc/httpd/apache.pem ' +
      '-out /etc/httpd/apache.pem -days 999 -nodes -subj ' +
      '"/O=scale/countryName=US/commonName=www.socallinuxexpo.org"'
end
