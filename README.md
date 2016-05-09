# scale-chef

## Getting started

!!!This is a work in progress!!!

You can bootstrap a node with

  chefctl -b

You can then run chef with:

  chefctl -i

Currently it uses the prefix of the hostname to determine the active file, so "www1" will get a www.json role and "db4" would get a db.json role.

This is heavily based on the facebook cookbooks.

Unless you pass in '--no-update', the chefrun will clone/update the relevant git-repos which, for scale-chef requires you to have some keys loaded, but also requires you to be root. This sucks, but I haven't fixed it yet.


