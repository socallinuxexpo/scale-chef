d = {}
if File.exists?('/etc/lists_secrets')
  File.read('/etc/lists_secrets').each_line do |line|
    k, v = line.strip.split(/\s*=\s*/)
    d[k.downcase] = v
  end
end

default['scale_phplist'] = {
  'mysql_db' => d['mysql_db'] || 'phplists',
  'mysql_user' => d['mysql_user'] || 'phplists',
  'mysql_password' => d['mysql_password'] || 'devpassword',
  'mysql_host' => d['mysql_host'] || 'db1',
  'bounce_mailbox_host' => d['bounce_mailbox_host'],
  'bounce_mailbox_user' => d['bounce_mailbox_user'],
  'bounce_mailbox_password' => d['bounce_mailbox_password'],
}

default[scale_phplist]['version'] = '3.2.5'
default[scale_phplist]['bounce_protocol'] = 'pop'
default[scale_phplist]['bounce_mailbox_port'] = '587/pop3/tls'
