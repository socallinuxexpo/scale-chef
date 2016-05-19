# vim:shiftwidth=2:expandtab

package ['mariadb', 'mariadb-server'] do
  action :upgrade
end

service 'mariadb' do
  action [:enable, :start]
end
