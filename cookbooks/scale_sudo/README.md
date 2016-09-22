scale_sudo Cookbook
====================
This cookbook installs sudo and provides an API to configure it.

Requirements
------------

Attributes
----------
* node['scale_sudo']['aliases']['host']
* node['scale_sudo']['aliases']['user']
* node['scale_sudo']['aliases']['command']
* node['scale_sudo']['defaults']
* node['scale_sudo']['users']

Usage
-----
Include `fb_sudo` to install sudo. By default users in the `sudo` group will 
be granted full access. Additional rules can be setup using 
`node['scale_sudo']['users']`.
