scale_apache Cookbook
=====================
Configuration for SCALE's various webservers.

Requirements
------------

Attributes
----------

Usage
-----
This doesn't provide an API - instead it uses the `fb_apache` API. There are a few recipes you can use:

### scale_apache::default
The main server recipe intended for www.socallinuxexpo.org.

### scale_apache::common
Stuff that needs to always go to all incarnations of our webservers. Currently just the CA root/intermediate cert.

### scale_apache::simple
A simple setup for things like lists and phpserv.
