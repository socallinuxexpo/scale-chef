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

default['scale_datadog']['monitors']['apache'] = {
  "init_config"=>nil,
  "instances"=>[{"apache_status_url"=>"http://localhost/server-status?auto"}]
}

default['scale_datadog']['monitors']['dns_check'] = {
   "init_config"=>{"default_timeout"=>4},
   "instances"=>[{"hostname"=>"www.socallinuxexpo.org", "nameserver"=>"8.8.8.8", "timeout"=>8}]
}

default['scale_datadog']['monitors']['linux_proc_extras'] = {
  "init_config"=>nil, "instances"=>[{"tags"=>[]}]
}
