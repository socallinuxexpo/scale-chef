scale_datadog Cookbook
======================

Requirements
------------

Attributes
----------
* node['scale_datadog']['config'][$CONFIG]
* node['scale_datadog']['monitors']

Usage
-----
### scale_datadog::default
The `default` recipe sets up the Datadog agent - installing the necessary packages, writing config files and starting the service.

`/etc/datadog-agent/datadog.yaml' is populated with key-value pairs from `node['scale_datadog']['config']`.

Individual monitors can be setup in `node['scale_datadog']['monitors']` - each entry in there will become a YAML file in `/etc/dd-agent/conf.d` - and all yaml files in there not configured by this cookbook will be deleted.

### scale_datadog::dd-handler
Sets up the Datadog chef-handler.
