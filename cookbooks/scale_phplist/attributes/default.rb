d = {}
if File.exists?('/etc/lists_secrets')
  File.read('/etc/lists_secrets').each_line do |line|
    k, v = line.strip.split(/\s*=\s*/)
    d[k.downcase] = v
  end
end

default['scale_phplist'] = {
  'mysql_host' => d['mysql_host'] || 'db1',
  'mysql_db' => d['mysql_db'] || 'phplists',
  'mysql_user' => d['mysql_user'] || 'phplists',
  'mysql_password' => d['mysql_password'] || 'devpassword',
}

default[scale_phplist]['version'] = '3.2.5'
