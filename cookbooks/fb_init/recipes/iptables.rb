node.default['fb_iptables']['filter']['INPUT']['policy'] = 'DROP'
node.default['fb_iptables']['filter']['FORWARD']['policy'] = 'DROP'
node.default['fb_iptables']['filter']['OUTPUT']['policy'] = 'ACCEPT'

{
  'no_invalid_state' => '-m conntrack --ctstate INVALID -j DROP',
  'allow_related_states' => 
    '-m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT',
}.each do |key, val|
  %w{INPUT OUTPUT}.each do |chain|
    node.default['fb_iptables']['filter'][chain]['rules'][key] = {
      'rule' => val,
    }
  end
end

{
  'allow_ssh' =>
    '-p tcp -m tcp --dport 22 --syn -m conntrack --ctstate NEW -j ACCEPT',
  'allow_https' => '-p tcp -m tcp --dport 443 -j ACCEPT',
  'allow_http' => '-p tcp -m tcp --dport 80 -j ACCEPT',
  'allow_loopback' => '-i lo -j ACCEPT',
}.each do |key, val|
  node.default['fb_iptables']['filter']['INPUT']['rules'][key] = {
    'rule' => val,
  }
}

node.default['fb_iptables']['filter']['INPUT']['rules']['allow_discovery'] = {
  'ip' => 6,
  'rule' => 
    '-d fe80::/64 -p udp -m udp --dport 546 -m conntrack --ctstate NEW -j ACCEPT',
}

{
  'allow_outgoing_tcp' => '-p tcp --syn -m conntrack --ctstate NEW -j ACCEPT',
  'allow_outgoing_non_tcp' => 
    '! -p tcp --syn -m conntrack --ctstate NEW -j ACCEPT',
}.each do |key, val|
  node.default['fb_iptables']['filter']['OUTPUT']['rules'][key] = {
    'rule' => val,
  }
}
