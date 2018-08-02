# scale-chef

## Getting started

!!!This is a work in progress!!!

Start up the VMs with `vagrant up` -- this will bootstrap the nodes and run
chef for the first time. Run `vagrant provision $vm` to rerun chef and
`vagrant ssh $vm` to get a shell. This assumes you have a ssh key that can
clone github loaded into your agent (which will get forwarded into the VMs).

You can also manually bootstrap a node with

```
/vagrant/scripts/chefctl.sh -b
```

You can then run chef with:

```
/vagrant/scripts/chefctl.sh -i
```

For development, use the `-V` flag to pull from your local repo (which is mounted into the VM on `/vagrant`) instead of pulling from github. If you're doing so after a fresh clone, remember to update the submodules first:

```
git submodule init
git submodule update
```

Currently it uses the prefix of the hostname to determine the active file, so "www1" will get a www.json role and "db4" would get a db.json role.

This is heavily based on the [facebook cookbooks](https://github.com/facebook/chef-cookbooks).

Unless you pass in '--no-update', the chefrun will clone/update the relevant git-repos which, for scale-chef requires you to have some keys loaded, but also requires you to be root. This sucks, but I haven't fixed it yet.

To get the webserver up and running, get a copy of the dynamic content (the
stuff under `httpdocs/sites/default/files`), copy it to
`/home/drupal/scale-drupal/httpdocs/sites/default/files` and make sure it's
owned by `root:apache`. Also get a copy of the static websites (`webroot`),
put it under `/home/webroot` and make sure it's owned by `root:root`.

To get the database up and running, get a dump, add

```
mysqladmin create scale_drupal
zcat /vagrant/SCALE14x-2016-04-24T17-26-57.mysql.gz | mysql -U scale_drupal
```

then setup a grant for the drupal user with (inside of `mysql -U mysql`):

```
GRANT ALL PRIVILEGES ON drupal.* TO 'drupal'@'scale-www1' IDENTIFIED BY 'thisisadevpassword' WITH GRANT OPTION;
```

To not get redirects you should edit `/home/drupal/scale-drupal/httpdocs/.htaccess` and remove the www rewrite rules. The cookbooks assume you are in dev mode if there are no prod secrets, but if you are testing with prod secrets you can force no redirects by touching `/etc/no_prod_redirects`

## Production secrets

For production machines use the `scale-secrets` repo, to manually setup the following secrets:

On All Hosts:
* common/datadog_secrets -> /etc/datadog_secrets

On role[lists]:
* lists/lists_secrets -> /etc/lists_secrets

On role[www]:
* www/drupal_secrets -> /etc/drupal_secrets

To get dev certs on a dev machine touch /etc/httpd/need_dev_keys and chef will create self-signed certs for you
