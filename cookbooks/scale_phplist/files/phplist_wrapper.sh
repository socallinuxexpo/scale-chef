#!/bin/bash

/usr/bin/php /home/website/public_html/lists/admin/index.php \
  -c /home/website/public_html/lists/config/config.php "$@"
