# scale-chef

## Getting started

You can also manually bootstrap a node by cloning the repo into
/var/chef/repo and running:

```
/var/chef/repo/scripts/chef_bootstrap.sh
```

You can then run chef with:

```
chefctl -i
```

This is heavily based on the [facebook cookbooks](https://github.com/facebook/chef-cookbooks).

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

## Testing Changes

You'll need to setup your environment. Run `./scripts/setup_dev.sh` to do so.

We use [Taste Tester](https://github.com/facebook/taste-tester/) for testing
changes. We have a wrapper for our specific settings. From the root of the
repo, you can run:

```
./scripts/tt test -s <host>
```

Then run `chefctl -i` on that host. You should put the results of your test in the PR.

To update your code on your taste-tester instance do:

```
./scripts/tt upload
```

Tests expire after an hour of idle and revert back to prod, but you can explicitly
untest with:

```
./scripts/tt untest -ys <hsot>
```

## Production secrets

For production machines use the `scale-secrets` repo, to manually setup the following secrets:

On All Hosts:
* common/datadog_secrets -> /etc/datadog_secrets

On role[lists]:
* lists/lists_secrets -> /etc/lists_secrets

On role[www]:
* www/drupal_secrets -> /etc/drupal_secrets

To get dev certs on a dev machine touch /etc/httpd/need_dev_keys and chef will create self-signed certs for you
