scale_ssh Cookbook
====================
This cookbook installs and configures ssh.

Requirements
------------

Attributes
----------
* node['scale_ssh']['keys'][$USER]
* node['scale_ssh']['sshd_config']

Usage
-----

Include `fb_ssh` to install ssh. Customize the daemon config with
`node['scale_ssh']['sshd_config']`. Add public keys for a given user with
`node['scale_ssh']['keys']`.
