# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
#
# Cookbook Name:: scale_certbot_hack
# Recipe:: default
#

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

# Always run our renewal script
cookbook_file '/usr/local/sbin/renew_certs.sh' do
  owner 'root'
  group 'root'
  mode '0755'
end
