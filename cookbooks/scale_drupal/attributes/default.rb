d = {}
if File.exists?('/etc/drupal_secrets')
  File.read('/etc/drupal_secrets').each_line do |line|
    k, v = line.strip.split(/\s*=\s*/)
    d[k.downcase] = v
  end
end

default['scale_drupal'] = {
  'drupal_hash_salt' => d['drupal_hash_salt'] || 'thisisadevhashsalt',
  'drupal_username' => d['drupal_username'] || 'drupal',
  'drupal_password' => d['drupal_password'] || 'thisisadevpassword',
  'drupal_database' => d['drupal_database'] || 'drupal',
}

if node.vagrant?
  default['scale_drupal']['mysql_host'] = 'scale-db1'
else
  default['scale_drupal']['mysql_host'] =
    'scale-drupal.cluster-c19nohpiwnoo.us-east-1.rds.amazonaws.com'
end
