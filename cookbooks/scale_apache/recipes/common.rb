#
# Cookbook Name:: scale_apache
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

node.default['fb_apache']['modules'] += [
  # everything in 00-base.conf (except what's in fb_apache)
  'access_compat',
  'actions',
  'alias',
  'allowmethods',
  'authn_anon',
  'authn_dbd',
  'authn_dbm',
  'authn_socache',
  'authz_dbd',
  'authz_dbm',
  'cache',
  'cache_socache',
  'data',
  'dbd',
  'dumpio',
  'echo',
  'expires',
  'ext_filter',
  'filter',
  'include',
  'info',
  'macro',
  'mime_magic',
  'remoteip',
  'reqtimeout',
  'request',
  'rewrite',
  'slotmem_plain',
  'slotmem_shm',
  'socache_dbm',
  'socache_memcache',
  'socache_shmcb',
  'status',
  'substitute',
  'suexec',
  'unique_id',
  'unixd',
  'userdir',
  'version',
  'vhost_alias',
  'watchdog',
  # and 00-ssl.conf
  'ssl',
  # 00-systemd.conf
  'systemd',
]
# reg is still c7 and doesn't have these
unless node.centos7?
  node.default['fb_apache']['modules'] += [
    'brotli',
    # 10-h2.conf
    'http2',
  ]
end

{
  'access_compat' => 'mod_access_compat.so',
  'allowmethods' => 'mod_allowmethods.so',
  'authn_socache' => 'mod_authn_socache.so',
  'authz_dbd' => 'mod_authz_dbd.so',
  'brotli' => 'mod_brotli.so',
  'cache_socache' => 'mod_cache_socache.so',
  'data' => 'mod_data.so',
  'dumpio' => 'mod_dumpio.so',
  'echo' => 'mod_echo.so',
  'macro' => 'mod_macro.so',
  'remoteip' => 'mod_remoteip.so',
  'request' => 'mod_request.so',
  'slotmem_plain' => 'mod_slotmem_plain.so',
  'slotmem_shm' => 'mod_slotmem_shm.so',
  'socache_dbm' => 'mod_socache_dbm.so',
  'socache_memcache' => 'mod_socache_memcache.so',
  'watchdog' => 'mod_watchdog.so',
  # 10-h2.conf
  'http2' => 'mod_http2.so',
}.each do |k, v|
  node.default['fb_apache']['modules_mapping'][k] = v
end

directory '/etc/httpd' do
  owner 'root'
  group 'root'
  mode '0755'
end

directory '/var/log/httpd' do
  owner 'root'
  group 'root'
  mode '0755'
end

include_recipe 'scale_apache::certs'

{
  'allow_https' =>
    '-p tcp -m tcp -m conntrack --ctstate NEW --dport 443 -j ACCEPT',
  'allow_http' =>
    '-p tcp -m tcp -m conntrack --ctstate NEW --dport 80 -j ACCEPT',
}.each do |key, val|
  node.default['fb_iptables']['filter']['INPUT']['rules'][key] = {
    'rule' => val,
  }
end
