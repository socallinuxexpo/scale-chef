# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

# This stuff should go in an ohai plugin or some-such
tier = node['fqdn'].split('.')[0].tr('0-9', '')
default['tier'] = tier

default['fb_init'] = {}
