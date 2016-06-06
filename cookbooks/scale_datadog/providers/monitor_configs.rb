def whyrun_supported?
  true
end

use_inline_resources

action :update do
  node['scale_datadog']['monitors'].to_hash.each do |monitor, config|
    template "/etc/dd-agent/conf.d/#{monitor}.yaml" do
      source 'monitor.yaml.erb'
      owner 'dd-agent'
      group 'root'
      mode '0644'
      variables(
        @config => config,
      )
    end
  end
end
