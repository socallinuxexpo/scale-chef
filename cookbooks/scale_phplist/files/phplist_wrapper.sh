#!/bin/bash

/usr/bin/php /var/www/html/lists/admin/index.php  \
  -c /var/www/html/lists/config/config.php "$@"
