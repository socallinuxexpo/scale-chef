default['scale_postfix'] = {
  'aliases' => {
    'postmaster' => 'root',
    'MAILER-DAEON' => 'postmaster'
  },
  'main.cf' => {
    'soft_bounce' => 'no',
    'queue_directory' => '/var/spool/postfix',
    'command_directory' => '/usr/sbin',
    'daemon_directory' => '/usr/libexec/postfix',
    'data_directory' => '/var/lib/postfix',
    'mail_owner' => 'postfix',
    'mydomain' => 'localhost',
    'inet_interfaces' => 'all',
    'inet_protocols' => 'all',
    'mydestination' =>
      '$myhostname, localhost.$mydomain, localhost',
    'unknown_local_recipient_reject_code' => '550',
    'alias_maps' => [
      'hash:/etc/postfix/aliases'
    ],
    'alias_database' => 'hash:/etc/postfix/aliases',
    'debug_peer_level' => '2',
    'sendmail_path' => '/usr/sbin/sendmail.postfix',
    'newaliases_path' => '/usr/bin/newaliases.postfix',
    'mailq_path' => '/usr/bin/mailq.postfix',
    'setgid_group' => 'postdrop',
    'html_directory' => 'no',
    'manpage_directory' => '/usr/share/man',
    'sample_directory' => '/usr/share/doc/postfix-2.10.1/samples',
    'readme_directory' => '/usr/share/doc/postfix-2.10.1/README_FILES',
    'debugger_command' =>
      'PATH=/bin:/usr/bin:/usr/local/bin:/usr/X11R6/bin' +
      'ddd $daemon_directory/$process_name $process_id & sleep 5',
  }
}

if File.exists?('/etc/postfix/sasl_passwd.db')
  default['scale_postfix']['main.cf']['smtp_sasl_auth_enable'] = 'yes'
  default['scale_postfix']['main.cf']['relayhost'] = 'smtp.mailgun.org'
  default['scale_postfix']['main.cf']['smtp_sasl_security_options'] = 'noanonymous'
  default['scale_postfix']['main.cf']['smtp_sasl_password_maps'] = 'hash:/etc/postfix/sasl_passwd'
end
