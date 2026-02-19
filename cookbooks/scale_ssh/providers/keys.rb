action :run do
  node['scale_ssh']['keys'].to_hash.each do |user, keys|
    file "/etc/ssh/authorized_keys/#{user}" do
      content keys.join("\n")
      owner 'root'
      group 'root'
      mode '0644'
    end
  end
end
