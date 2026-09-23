# This is a short-term hack.
#
# We've had several instances where dbus-broker crashes, NetworkManager
# goes with it, never restarts, and we eventually lose our DHCP address.
#
# So, for now, make sure NM is always started. In the long-term we should
# move to networkd for which we already have good Chef support for and
# which is better suited for servers.

# Don't mess with networking on firstboot when we may be transitioning
# between things.
return if node.firstboot_any_phase?

# keep this up-to-date, nothing else does, we should get this
# info fb_systemd probably
package 'dbus-broker' do
  action :upgrade
end

service 'NetworkManager' do
  # don't break CI
  only_if { ::File.exist?('/usr/lib/systemd/system/NetworkManager.service') }
  action [:enable, :start]
end
