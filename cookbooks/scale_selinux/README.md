scale_selinux Cookbook
====================
Basic cookbook to setup selinux.

Requirements
------------

Attributes
----------
* node['scale_selinux']['state']
* node['scale_selinux']['type']

Usage
-----
Just include it; `node['scale_selinux']['state']` is one of `enforcing`,
`permissive` or `disabled` (default). `node['scale_selinux']['type']` is one
of `targeted` (default), `minimum` or `mls`.
