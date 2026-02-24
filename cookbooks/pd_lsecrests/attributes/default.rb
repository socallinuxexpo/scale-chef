d = {}
if File.exist?('/etc/chef_secrets')
  Chef::Log.info('[pd_lsecrets] Loading secrets')
  File.read('/etc/chef_secrets').each_line do |line|
    k, v = line.strip.split(/\s*=\s*/)
    d[k.downcase] = v
  end
end

default['pd_lsecrets'] = d
