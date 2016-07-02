# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

# This stuff should go in an ohai plugin or some-such
tier = node['fqdn'].split('.')[0].tr('0-9', '').split('-')[1]
org = node['fqdn'].split('.')[0].tr('0-9', '').split('-')[1]

default['tier'] = tier
default['org'] = org

default['fb_init'] = {}
