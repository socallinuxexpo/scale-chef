d = {}
if File.exists?('/etc/drupal_secrets')
  File.read('/etc/drupal_secrets').each_line do |line|
    k, v = line.strip.split(/\s*=\s*/)
    d[k.downcase] = v
  end
end

default['scale_apache'] = {
  'drupal_hash_salt' => d['drupal_hash_salt'] || 'thisisadevhashsalt',
  'drupal_password' => d['drupal_password'] || 'thisisadevpassword',
  's3_aws_access_key_id' => d['s3_aws_access_key_id'] || 'thisisadevkey',
  's3_aws_secret_access_key' => d['s3_aws_secret_access_key'] || 'thisisadevsecret',
  'mysql_host' => d['mysql_host'] || 'db1',
  'drupal_database' => d['drupal_database'] || 'drupal',
  'want_prod_redirects' => !d.empty? && !File.exists?('/etc/no_prod_redirects'),
}
