# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
name 'fb_init'
maintainer 'SCALE'
maintainer_email 'noreply@socallinuxexpo.org'
license 'Apache 2.0'
description 'SCALE version of fb_init'
source_url 'https://github.com/socallinuxexpo/scale-chef'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '0.0.1'
%w{
  fb_cron
  fb_dnf
  fb_fstab
  fb_helpers
  fb_hostconf
  fb_hosts
  fb_iptables
  fb_limits
  fb_logrotate
  fb_modprobe
  fb_motd
  fb_postfix
  fb_securetty
  fb_sudo
  fb_swap
  fb_sysctl
  fb_syslog
  fb_systemd
  scale_chef_client
  scale_datadog
  scale_selinux
  scale_ssh
  scale_users
  scale_yum
}.each do |cb|
  depends cb
end
