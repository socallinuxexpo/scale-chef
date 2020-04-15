# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

# This stuff should go in an ohai plugin or some-such
shorthostname = node['hostname']
trimmed_hostname = shorthostname.tr('0-9', '')
pieces = trimmed_hostname.split('-')

env = 'prod'
tier = pieces[1]

default['tier'] = tier
default['env'] = env

default['fb_init'] = {}
