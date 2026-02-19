scale_chef_client Cookbook
==========================
Simple cookbook to setup the chef client.

Requirements
------------

Attributes
----------
* node['scale_chef_client']['cookbook_dirs']
* node['scale_chef_client']['role_dir']

Usage
-----

`scale_chef_client` assumes a [Taste
Tester](https://github.com/facebook/taste-tester) model and thus sets
`/etc/chef/client.rb` as a symlink to `/etc/chef/client-prod.rb`.

The `client-prod.rb` is a template and sets up a minimal chef-solo-compatible
config using the attributes specified above.

In addition, `/etc/chef/runlist.json` is a Chef additional attributes file with
a runlist in it. This runlist is always `recipe[fb_init]` followed by
`role[$TIER]` where $TIER is `node['tier']` which is populated, currently, by
`fb_init`'s attributes file (but should be moved to Ohai).
