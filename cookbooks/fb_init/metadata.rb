# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
name 'fb_init'
maintainer 'SCALE'
maintainer_email 'noreply@socallinuxexpo.org'
license 'Apache 2.0'
description 'SCALE version of fb_init'
source_url 'https://github.com/facebook/chef-cookbooks/'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '0.0.1'
%w{
  scale_chef_client
  scale_datadog
  scale_sudo
  scale_ssh
  scale_users
  fb_cron
  fb_fstab
  fb_helpers
  fb_hostconf
  fb_hosts
  fb_limits
  fb_logrotate
  fb_modprobe
  fb_motd
  fb_swap
  fb_securetty
  fb_sysctl
  fb_syslog
  fb_systemd
}.each do |cb|
  depends cb
end
