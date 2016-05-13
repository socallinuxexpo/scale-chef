execute 'generate dev keys' do
  creates '/etc/httpd/apache.pem'
  command 'openssl req -x509 -newkey rsa:2048 -keyout /etc/httpd/key.pem ' +
      '-out /etc/httpd/cert.pem -days 999 -nodes -subj ' +
      '"/O=scale/countryName=US/commonName=www.socallinuxexpo.org"' +
      '; cat /etc/httpd/key.pem /etc/httpd/cert.pem > /etc/httpd/apache.pem'
end
