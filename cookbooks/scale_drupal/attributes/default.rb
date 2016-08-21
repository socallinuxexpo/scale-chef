d = {}
if File.exists?('/etc/drupal_secrets')
  File.read('/etc/drupal_secrets').each_line do |line|
    k, v = line.strip.split(/\s*=\s*/)
    d[k.downcase] = v
  end
end

default['scale_drupal'] = {
  'drupal_hash_salt' => d['drupal_hash_salt'] || 'thisisadevhashsalt',
  'drupal_password' => d['drupal_password'] || 'thisisadevpassword',
  'drupal_database' => d['drupal_database'] || 'scale_drupal',
}

if node.vagrant?
  default['scale_drupal']['mysql_host'] = 'scale-db1'
else
  default['scale_drupal']['mysql_host'] =
    '26b289196faa9f09e8b99de13aa19528986e9b68.rackspaceclouddb.com'
end
