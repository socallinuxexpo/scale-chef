# This is where you set your own stuff...

# Make sure the perms for our secrets files are good
file '/etc/chef_secrets' do
  owner 'root'
  group 'root'
  mode '0600'
end

node.default['scale_chef_client']['cookbook_dirs'] = [
  '/var/chef/repo/cookbooks',
]
node.default['scale_chef_client']['role_dir'] =
  '/var/chef/repo/roles'

if node.vagrant?
  node.default['fb_sudo']['users']['vagrant'] = {
    'vagrant has full access on dev VMs' => 'ALL=NOPASSWD: ALL',
  }
end

d = {}
if File.exists?('/etc/datadog_secrets')
  File.read('/etc/datadog_secrets').each_line do |line|
    k, v = line.strip.split(/\s*=\s*/)
    d[k.downcase] = v
  end
  if d['application_key']
    node.default['scale_datadog']['config']['application_key'] =
      d['application_key']
  end
  if d['api_key']
    node.default['scale_datadog']['config']['api_key'] = d['api_key']
  end
end

{
  'abuse' => 'postmaster',
  'decode' => 'root',
  'postmaster' => 'root',
  'root' => 'root@socallinuxexpo.org',
  'scale-voicemail' => 'scale-chairs',
  'spam' => 'postmaster',
  'MAILER-DAEMON' => 'postmaster',
}.each do |src, dst|
  node.default['fb_postfix']['aliases'][src] = dst
end

if File.exist?('/etc/postfix/skip_mailgun')
  Chef::Log.warn("fb_init: Skipping mailgun postfix setup!")
elsif File.exist?('/etc/sasl_passwd')
  if node.el_min_version?(10) || node.eln?
    map_type = 'lmdb'
  else
    map_type = 'hash'
  end
  {
    'smtp_sasl_auth_enable' => 'yes',
    'relayhost' => 'smtp.mailgun.org',
    'smtp_sasl_security_options' => 'noanonymous',
    'smtp_sasl_password_maps' => "#{map_type}:/etc/postfix/sasl_passwd",
  }.each do |k, v|
    node.default['fb_postfix']['main.cf'][k] = v
  end

  node.default['fb_postfix']['sasl_passwd']['smtp.mailgun.org'] =
    File.read('/etc/sasl_passwd').chomp.split(' ')[1]
else
  fail 'fb_init: /etc/sasl_passwd is missing, cannot setup mailgun'
end

node.default['fb_postfix']['main.cf']['mydomain'] = 'localhost'

pkgs = %w{postfix-perl-scripts cyrus-sasl-plain cyrus-sasl-md5}
if node.el_max_version?(8)
  pkgs << 'atop'
end

package pkgs do
  action :upgrade
end

queues = ['incoming', 'active', 'deferred']
node.default['scale_datadog']['monitors']['postfix'] = {
  'init_config' => nil,
  'instances' => [{
    'directory' => '/var/spool/postfix',
    'queues' => queues,
  }],
}

queues.each do |q|
  # the docs say they use /usr/bin/find, but they seem to use /bin/find
  # so just allow for both...
  node.default['fb_sudo']['users']['dd-agent']["postfix_#{q}"] =
    "ALL=(ALL) NOPASSWD:/usr/bin/find /var/spool/postfix/#{q} -type f," +
    "/bin/find /var/spool/postfix/#{q} -type f"
end

# NOTE: this is technically the default, but because we end up
# doing DHCPV6, network-scripts turns it back off. Which is dumb
# and what we really want is to set `IPV6_SET_SYCTL=no` in
# the ifcfg files, but not sure how to get cloud-init to do that
# so in the meantime we work around it with this
node.default['fb_sysctl']['net.ipv6.conf.all.accept_ra'] = 1
node.default['fb_sysctl']['net.ipv6.conf.default.accept_ra'] = 1
node.default['fb_sysctl'][
  "net.ipv6.conf.#{node['network']['default_interface']}.accept_ra"] = 1

cookbook_file '/etc/cloud/cloud.cfg.d/99-custom-networking.cfg' do
  # This should apply to 8+
  not_if { node.centos6? || node.centos7? }
  owner 'root'
  group 'root'
  mode '0644'
end

# Remove once we've ported over all cookbooks to fb_yum_repos
node.default['fb_yum_repos']['manage_repos'] = false

include_recipe 'fb_init::iptables_settings'

to_remove = %w{
  rpcbind
  abrt
}

# c8s and later preinstall cockpit, do not want
unless node.centos7?
  to_remove += %w{
    cockpit-system
    cockpit-ws
    cockpit-bridge
  }
end

package to_remove do
  action :remove
end

# 32-bit systemd doesn't belong here
package 'systemd-libs' do
  arch 'i686'
  action :remove
end

node.default['fb_syslog']['rsyslog_early_lines'] += [
  'global(workDirectory="/var/lib/rsyslog")',
  'module(load="imjournal" UsePid="system" FileCreateMode="0644"' +
    ' StateFile="imjournal.state")',
]
