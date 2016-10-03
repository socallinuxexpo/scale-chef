# vim:shiftwidth=2:expandtab

# this isn't used in prod, so we don't care about it being open to the world
node.default['fb_iptables']['filter']['INPUT']['rules']['allow_mysql'] = {
  'rule' => '-p tcp -m tcp -m conntrack --ctstate NEW --dport 3306 -j ACCEPT',
}

package ['mariadb', 'mariadb-server'] do
  action :upgrade
end

service 'mariadb' do
  action [:enable, :start]
end
