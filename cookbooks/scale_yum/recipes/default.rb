# vim:shiftwidth=2:expandtab

execute 'enable crb' do
  not_if 'dnf repolist | grep crb'
  command 'dnf config-manager --set-enabled crb'
end

package 'epel-release' do
  action :upgrade
end
