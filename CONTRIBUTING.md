# Contributing to scale-chef

Hi and welcome to scale-chef. We're happy that you want to contribute, and this document will walk you through how to do this.

The first thing you need to know is this repo follows the Facebook Attribute-driven API model of Chef. This means no environments or cookbook versions. You can find information on this model at their [repo](https://github.com/facebook/chef-cookbooks), specifically the [README](https://github.com/facebook/chef-cookbooks/blob/master/README.md) and the referenced [Philosophy](https://github.com/facebook/chef-utils/blob/master/Philosophy.md).

## Some layout considerations

* `fb_*` - These are copied from the Facebook repo except for `fb_init` which is forked from `fb_init_swample` (as dictated by the README.md there). Do not change these here unless you have a PR upstream as well - these should be in-sync.
* `scale_*` - These are our scale-specific cookbooks. Some of them are fb-style API cookbooks while others are "leaf" cookbooks that just set things up. If there is an API it is documented in the `README.md` for that cookbook.
* `fb_init` forks to `site_settings` which is the SCALE defaults for FB cookbooks. Later cookbooks further tweak these settings.

## Development and Testing

There are two ways to test: vagrant and taste-tester.

`vagrant` will spin-up VMs on your box and allow you to iterate quickly and break things at will. You should use this to do basic development until you feel your code is correct and works. At this point you may send a PR if you'd like.

Before your PR can be merged, you must also use taste-tester on the dev environment. Taste-tester will setup a chef-zero instance on your machine and then change the configuration of some machine in our production rackspace network to point at your chef-zero instance. You should use the test instance of the machine you're targeting. So if you are targeting `scale-www1` then use `scale-www-test1` and so-on. These map to public hostnames just as you'd expect: www-test.socallinuxexpo.org and such.

### Vagrant

You'll need virtualbox installed (or some other backend for vagrant, we recommend virtualbox) and a reasonably modern vagrant. From there, in the root of the repo you can type `vagrant up` to create three VMs: scale-www1, scale-lists1, and scale-db1. These are duplicates of the prod environment with the exception of scale-db1 (prod uses the rackspace DB-as-a-service).

Note that for some distros, the plugins are not installed, so if you get errors try running:

```
vagrant plugin install vagrant-cachier
vagrant plugin install vagrant-hostmanager
```

From there you can `vagrant ssh scale-www1` or whatever else. You should use the `-V` flag to `chefctl` so that it will pull from your repo. In otherwords development looks like this:

* WINDOW 1: edit some stuff

* WINDOW 2: `vagrant ssh scale-www1`
* WINDOW 2: `/vagrant/scripts/chefctl.sh -iV`

* WINDOW 1: fix stuff

* WINDOW 2: `/vagrant/scripts/chefctl.sh -iV`

When you're done you can `vagrant halt` to shutdown everything.

### Taste-tester

#### Pre-requisites
To use taste-tester you will want to install [RVM](https://rvm.io/). If you're not familiar with RVM it's like VirtualEnv for python - it's gives you a separate ruby environment in your home directory so you can install gems and do other things without messing with your system ruby. Once it's installed do `rvm install 2.3.0` to install a recent Ruby.

You won't need to do the `install` ever again (until you change versions), but you'll want to run `rvm use 2.3.0` to update your environment to use the RVM ruby (do `rvm reset` to go back).

Then you can install the development dependencies by running `bundle install`.

Also note you will need an actual account on SCALE systems to do taste-testing. This means if you're a SCALE staff, file an Issue to get access with a public key and desired username included. If you're not, then a staff member will test your diff for you (please allow some time for someone to do this).
 
#### Usage

OK, so now when you're ready to test, make sure you've run `rvm use 2.3.0`. We provide a wrapper around taste-tester to use the right version and use the embedded config. So to test do:

```
scripts/tt test -ys <host>
```

If the user on your local system isn't the same as the remote user, pass in `--user <user>`.

Now ssh to the system and run `sudo chefctl -i` and ensure it has the desired effect.

After 1 hour the machine will automatically revert to prod, but you can untest with `scripts/tt untest -ys <host>`
