#
# Cookbook Name:: scale_datadog
# Recipe:: dd-handler
#
# Copyright 2011-2015, Datadog
# Copyright 2016, SCALE
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'uri'

if Chef::Config[:why_run]
  # chef_handler 1.1 needs us to require datadog handler's file,
  # which makes why-run runs fail when chef-handler-datadog is not installed,
  # so skip the recipe when in why-run mode until we can use chef_handler 1.2
  Chef::Log.warn('Running in why-run mode, skipping dd-handler')
  return
end

unless File.exist?('/etc/datadog_secrets')
  Chef::Log.warn('No /etc/datadog_secrets, skipping datadog setup')
  return
end

include_recipe 'chef_handler'

chef_gem 'chef-handler-datadog' do # ~FC009
  action :install
  compile_time true
end
require 'chef/handler/datadog'

handler_config = {
  :api_key => node['scale_datadog']['config']['api_key'],
  :application_key => node['scale_datadog']['config']['application_key'],
  :tag_prefix => 'tag:'
}

# Create the handler to run at the end of the Chef execution
chef_handler 'Chef::Handler::Datadog' do
  source 'chef/handler/datadog'
  arguments [handler_config]
  supports :report => true, :exception => true
  action :nothing
end.run_action(:enable)
