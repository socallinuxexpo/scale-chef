remote_file '/etc/ssl/certs/rds-combined-ca-bundle.pem' do
  source 'https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem'
  owner 'root'
  group 'root'
  mode '0644'
end
