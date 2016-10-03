# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

# This stuff should go in an ohai plugin or some-such
shorthostname = node['fqdn'].split('.')[0]
trimmed_hostname = shorthostname.tr('0-9', '')
pieces = trimmed_hostname.split('-')
if pieces.size == 3
  env = pieces[2]
else
  env = 'prod'
end
org = pieces[0]
tier = pieces[1]

default['tier'] = tier
default['org'] = org
default['env'] = env

default['fb_init'] = {}
