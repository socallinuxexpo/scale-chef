# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

# This stuff should go in an ohai plugin or some-such
shorthostname = node['hostname']
trimmed_hostname = shorthostname.tr('0-9', '')
pieces = trimmed_hostname.split('-')

env = 'prod'
tier = pieces[1]

default['tier'] = tier
default['env'] = env

d = {}
if File.exist?('/etc/chef_secrets')
  File.read('/etc/chef_secrets').each_line do |line|
    k, v = line.strip.split(/\s*=\s*/)
    d[k.downcase] = v
  end
end

default['fb_init'] = {
  'secrets' => d,
}
