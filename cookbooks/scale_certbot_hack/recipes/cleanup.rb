directory '/usr/local/certbot-venv' do
  recursive true
  action :delete
end

file '/usr/local/sbin/renew_certs.sh' do
  action :delete
end
