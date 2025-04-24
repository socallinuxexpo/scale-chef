default['scale_drupal'] = {
  'drupal_database' => 'drupal',
  'mysql_host' => node.vagrant? ? 'scale-db1' :
    'scale-drupal.cluster-c19nohpiwnoo.us-east-1.rds.amazonaws.com',
}
