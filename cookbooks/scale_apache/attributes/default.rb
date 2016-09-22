d = {}
if File.exists?('/etc/drupal_secrets')
  File.read('/etc/drupal_secrets').each_line do |line|
    k, v = line.strip.split(/\s*=\s*/)
    d[k.downcase] = v
  end
end

default['scale_apache'] = {
  's3_aws_access_key_id' => d['s3_aws_access_key_id'] || 'thisisadevkey',
  's3_aws_secret_access_key' =>
      d['s3_aws_secret_access_key'] || 'thisisadevsecret',
  'want_prod_redirects' => !d.empty? && !File.exists?('/etc/no_prod_redirects'),
}
