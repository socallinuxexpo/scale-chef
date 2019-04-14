#!/bin/bash

# This is how I got the certs:

# FOR WWW
# certbot certonly --cert-name socallinuxexpo.org
#  -w /home/drupal/scale-drupal/httpdocs
#  -d socallinuxexpo.org,www.socallinuxexpo.org
#  --webroot -n --rsa-key-size 4096

# FOR REG
# certbot certonly --cert-name register.socallinuxexpo.org
#  -w /var/www/html -d register.socallinuxexpo.org,reg.socallinuxexpo.org
#  --webroot -n --rsa-key-size 4096

# FOR LISTS
# certbot certonly --cert-name lists.socallinuxexpo.org
#  -w /var/www/html -d lists.socallinuxexpo.org,lists.linuxfests.org
#  --webroot -n --rsa-key-size 4096

certbot renew --post-hook "systemctl restart httpd" -q --rsa-key-size 4096
