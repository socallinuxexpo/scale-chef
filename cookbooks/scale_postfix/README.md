scale_postfix Cookbook
======================
Simple generic cookbook for controlling postfix

Requirements
------------

Attributes
----------
* node['scale_postfix']['main.cf'][$KEY]
* node['scale_postfix']['aliases'][$SRC]

Usage
-----
This cookbook is designed to be used with the Facebook cookbooks and follows in that style. Schedule it in fb_init where the comment denotes.

This may be contribued to Facebook's chef-cookbooks at some point if we flush out support more.

### main.cf
Any value in main.cf can be representeded under the `main.cf` hash. If the value is an array, the values will be joined as comma-separated strings, per postfix's expectation.

The only default value that is an array is `alias_maps`.

Modifying things is simple:

```ruby
node.default['scale_postfix']['main.cf']['mydomain'] = 'www.foo.com'
```

### Aliases
Aliases will be added to /etc/postfix/aliases. They are a simple hash:

```ruby
node.default['scale_postfix']['aliases']['president'] = 'dingdong'
```
