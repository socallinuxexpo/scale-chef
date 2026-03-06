git 'sync-scripts' do
  repository 'https://github.com/socallinuxexpo/scale-sync-scripts.git'
  revision 'main'
  action :sync
  destination '/usr/local/scale-sync-scripts'
end

template '/etc/scale_email_sync.yml' do
  owner 'apache'
  group 'apache'
  mode '0640'
end

node.default['fb_cron']['jobs']['scale_email_sync'] = {
  'command' => '/usr/local/scale-sync-scripts/listmonk/scale_email_sync.py' +
    ' --prod-lists &>/dev/null',
  'user' => 'apache',
  'time' => '5 * * * *',
}
