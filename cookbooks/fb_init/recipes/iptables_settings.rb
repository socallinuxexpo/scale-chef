%w{INPUT FORWARD OUTPUT}.each do |chain|
  node.default['fb_iptables']['filter'][chain]['policy'] = 'DROP'
end

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

input_rules = {
  'allow_ssh' =>
    '-p tcp -m tcp --dport 22 --syn -m conntrack --ctstate NEW -j ACCEPT',
  'allow_loopback' => '-i lo -j ACCEPT',
}

if node.vagrant?
  input_rules['allow_vagrant_ssh'] =
    '-p tcp -m tcp --dport 2222 --syn -m conntrack --ctstate NEW -j ACCEPT'
end

input_rules.each do |key, val|
  node.default['fb_iptables']['filter']['INPUT']['rules'][key] = {
    'rule' => val,
  }
end

{
  'allow_outgoing_tcp' => '-p tcp --syn -m conntrack --ctstate NEW -j ACCEPT',
  'allow_outgoing_non_tcp' => '! -p tcp -m conntrack --ctstate NEW -j ACCEPT',
}.each do |key, val|
  node.default['fb_iptables']['filter']['OUTPUT']['rules'][key] = {
    'rule' => val,
  }
end
