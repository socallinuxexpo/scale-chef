d = {}
if File.exists?('/etc/drupal_secrets')
  File.read('/etc/drupal_secrets').each_line do |line|
    k, v = line.split(/\s*=\s*/)
    d[k.downcase] = v.downcase
  end
end

default['scale_apache'] = {
  'drupal_hash_salt' => d['drupal_hash_salt'] || 'thisisadevhashsalt',
  'drupal_password' => d['drupal_password'] || 'thisisadevpassword',
}
