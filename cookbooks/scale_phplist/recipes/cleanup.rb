
Dir.glob("/usr/local/phplist-*").each do |dir|
  directory dir do
    recursive true
    action :delete
  end
end

file '/usr/local/sbin/phplist_wrapper' do
  action :delete
end

pkgs = [
  'php', 'php-mysqlnd', 'php-imap', 'remi-release-9'
]

package pkgs do
  action :remove
end
