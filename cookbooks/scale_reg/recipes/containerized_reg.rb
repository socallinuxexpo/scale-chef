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

include_recipe 'fb_letsencrypt'

name = 'register.socallinuxexpo.org'

%w{crt key}.each do |type|
  link "/etc/nginx/apache.#{type}" do
    to FB::LetsEncrypt.send(type.to_sym, node, name)
  end
end

unless ::File.exist?('/etc/nginx/apache.key')
  Chef::Log.info(
    "Skipping nginx setup due to ordering issue. This run will set up " +
    "key links, if available, and next run will setup nginx"
  )
  node.default['fb_nginx']['enable'] = false
  return
end

node.default['fb_nginx']['sites']['reg-80'] = {
  'listen 80' => nil,
  'listen [::]:80' => nil,
  'server_name' => 'reg.socallinuxexpo.org',
  'location ^~ /.well-known/acme-challenge/' => {
    'root' => '/var/www/html',
  },
  'location /' => {
    'return 301' => 'https://$host$request_uri',
  },
}

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
