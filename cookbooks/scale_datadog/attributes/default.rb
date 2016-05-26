# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

default['scale_datadog'] = {
  'config' => {
    'dd_url' => 'https://app.datadoghq.com',
    'api_key' => nil,
  },
}
