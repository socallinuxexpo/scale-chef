# INPUT rules (inbound http(s) requests)
{
  'allow_https' =>
    '-p tcp -m tcp -m conntrack --ctstate NEW --dport 443 -j ACCEPT',
  'allow_http' =>
    '-p tcp -m tcp -m conntrack --ctstate NEW --dport 80 -j ACCEPT',
}.each do |key, val|
  node.default['fb_iptables']['filter']['INPUT']['rules'][key] = {
    'rule' => val,
  }
end

# FORWARD rules (for container)
{
  'allow_container_outbound' =>
    '-i podman0 -m conntrack --ctstate NEW -j ACCEPT',
  'no_invalid_state' =>
    '-m conntrack --ctstate INVALID -j DROP',
  'allow_related_states' =>
    '-m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT',
}.each do |key, val|
  node.default['fb_iptables']['filter']['FORWARD']['rules'][key] = {
    'rule' => val,
  }
end

include_recipe 'fb_nginx'

node.default['fb_nginx']['enable_default_site'] = false

include_recipe 'scale_certbot_hack'

# TODO: move to fb_letsencrypt
# https://github.com/socallinuxexpo/scale-chef/issues/374
node.default['fb_cron']['jobs']['renew_certs'] = {
  'command' => '/usr/local/sbin/renew_certs.sh',
  'time' => '1 1 * * *',
}

link '/etc/nginx/apache.crt' do
  to '/etc/letsencrypt/live/register.socallinuxexpo.org/fullchain.pem'
end

link '/etc/nginx/apache.key' do
  to '/etc/letsencrypt/live/register.socallinuxexpo.org/privkey.pem'
end

unless ::File.exist?('/etc/nginx/apache.key')
  Chef::Log.info(
    "Skipping nginx setup due to ordering issue. This run will set up " +
    "key links, if available, and next run will setup nginx"
  )
  node.default['fb_nginx']['enable'] = false
  return
end

node.default['fb_nginx']['sites']['reg'] = {
  'listen 443' => 'ssl',
  'listen [::]:443' => 'ssl',
  'server_name' => 'reg.socallinuxexpo.org',
  'ssl_certificate' => '/etc/nginx/apache.crt',
  'ssl_certificate_key' => '/etc/nginx/apache.key',
  'location /' => {
    'proxy_pass' => 'http://localhost:8080',
    'proxy_set_header Host' => '$host',
    'proxy_set_header X-Forwarded-Proto' => 'https',
    'proxy_set_header X-Forwarded-For' => '$proxy_add_x_forwarded_for',
    'proxy_set_header X-Real-Ip' => '$remote_addr',
  },
}

service 'scale-reg' do
  action [:enable, :start]
end
