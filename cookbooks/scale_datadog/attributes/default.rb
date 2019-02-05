# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

default['scale_datadog'] = {
  'config' => {
    'dd_url' => 'https://app.datadoghq.com',
    'api_key' => nil,
    'application_key' => nil,
    'log_to_syslog' => 'no',
    'logs_enabled' => true,
    'process_config' => {
      'enabled' => true,
    },
  },
  'monitors' => {},
}
