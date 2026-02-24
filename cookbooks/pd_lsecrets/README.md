pd_lsecrets Cookbook
====================
A really simple cookbook to load secrets from a local file.

In the event you already have a way to distribute secrets to hosts,
things like Chef Vault may not be what you want. This cookbook provides a
simple way of loading secrets from a local file, `/etc/chef_secrets`, and
making them available in attributes.

The security here has many trade-offs. The secrets file is not encrypted,
but then again, these secrets are likely going into files on disk anyway.

Requirements
------------

Attributes
----------
* node['pd_lsecrets']['secret1']

Usage
-----

Include the `pd_lsecrets` recipe in your run list. Then, create a file at
`/etc/chef_secrets` with the following format:

```text
secret1=secret_value
```

Secret names will always be downcased, so the casing in the file is not important.

You can then use your secrets with:

```ruby
node['pd_lsecrets']['secret1']
```

The secrets file is parsed at attribute time, so they are available very early.

You should include the recipe as early in your runlist as possible as it ensures,
safe permissions on the file.
