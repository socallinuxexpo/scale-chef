# scale-chef

## Getting started

!!!This is a work in progress!!!

Start up the VMs with `vagrant up` -- this will bootstrap the nodes and run
chef for the first time. Run `vagrant provision $vm` to rerun chef and 
`vagrant ssh $vm` to get a shell. This assumes you have a ssh key that can
clone github loaded into your agent (which will get forwarded into the VMs).

You can also manually bootstrap a node with

  /vagrant/scripts/chefctl -b

You can then run chef with:

  /vagrant/scripts/chefctl -i

Currently it uses the prefix of the hostname to determine the active file, so "www1" will get a www.json role and "db4" would get a db.json role.

This is heavily based on the [facebook cookbooks](https://github.com/facebook/chef-cookbooks).

Unless you pass in '--no-update', the chefrun will clone/update the relevant git-repos which, for scale-chef requires you to have some keys loaded, but also requires you to be root. This sucks, but I haven't fixed it yet.
