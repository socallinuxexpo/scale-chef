scale_apache Cookbook
=====================
Configuration for SCALE's various webservers.

Requirements
------------

Attributes
----------

Usage
-----
### scale_apache::common
Stuff that needs to always go to all incarnations of our webservers. Currently
just the CA root/intermediate cert.

### scale_apache::simple
A simple setup for things like lists and phpserv.
