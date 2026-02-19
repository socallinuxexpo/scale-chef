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

unless node['fb_init']['secrets']['datadog_api_key']
  Chef::Log.warn('No Datadog secrets available, skipping datadog setup')
  return
end

chef_gem 'chef-handler-datadog' do
  action :install
  compile_time true
end
require 'chef/handler/datadog'

handler_config = {
  :api_key => node['fb_init']['secrets']['datadog_api_key'],
  :application_key => node['fb_init']['secrets']['datadog_application_key'],
  :tag_prefix => 'tag:',
}

# Create the handler to run at the end of the Chef execution
chef_handler 'Chef::Handler::Datadog' do
  source 'chef/handler/datadog'
  arguments [handler_config]
  type :report => true, :exception => true
  action :nothing
end.run_action(:enable)
