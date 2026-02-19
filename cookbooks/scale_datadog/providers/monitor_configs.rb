action :update do
  Dir.glob('/etc/datadog-agent/conf.d/*.yaml').each do |f|
    basename = ::File.basename(f, '.yaml')
    next if node['scale_datadog']['monitors'].keys.include?(basename)
    file f do
      action :delete
    end
  end

  node['scale_datadog']['monitors'].to_hash.each do |monitor, config|
    template "/etc/datadog-agent/conf.d/#{monitor}.d/#{monitor}.yaml" do
      source 'monitor.yaml.erb'
      owner 'dd-agent'
      group 'root'
      mode '0644'
      variables({
                  :config => config,
                })
    end
  end
end
