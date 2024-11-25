scale_mailman Cookbook
======================
Cookbook to install mailman for use by linuxfests and scale.

Requirements
------------

Attributes
----------

Usage
-----
As of now this simply uses the `fb_postfix` API to set things up and then
sets up SCALE lists. Genericification to come.

### mailman3 initial setup notes

You can run `mailman-web migrate` to setup the DB tables.

We had to touch and chown the uwsgi logfiles in `/var/log/mailman3`:
`uwsgi.log`, `uwsgi-error.log`, `uwsgi-qcluster.log`.

We also had to touch and chown `/var/spool/mail/mailman`.

You create the initial mailman superuser by:

```bash
su - mailman
mailman-web createsuperuser
```
