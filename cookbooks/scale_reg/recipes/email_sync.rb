cookbook_file '/usr/local/bin/scale_email_sync' do
  source 'scale_email_sync.py'
  owner 'root'
  group 'root'
  mode '0755'
end

template '/etc/scale_email_sync.yml' do
  owner 'apache'
  group 'apache'
  mode '0640'
end

node.default['fb_cron']['jobs']['scale_email_sync'] = {
  'command' => '/usr/local/bin/scale_email_sync --prod-lists &>/dev/null',
  'user' => 'apache',
  'time' => '5 * * * *',
}
