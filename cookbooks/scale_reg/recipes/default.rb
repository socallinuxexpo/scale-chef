#
# Cookbook Name:: scale_reg
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

if node.centos_min_version?(10)
  include_recipe '::containerized_reg'
else
  include_recipe '::native_reg'
end
