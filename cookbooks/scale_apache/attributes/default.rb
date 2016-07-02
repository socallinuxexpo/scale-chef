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
  'drupal_database' => d['drupal_database'] || 'drupal',
  'want_prod_redirects' => !d.empty? && !File.exists?('/etc/no_prod_redirects'),
}

if node.vagrant?
  default['scale_apache']['mysql_host'] = 'db1'
else
  default['scale_apache']['mysql_host'] = '26b289196faa9f09e8b99de13aa19528986e9b68.rackspaceclouddb.com'
end
