accept_env = %w{
  LANG
  LC_CTYPE
  LC_NUMERIC
  LC_TIME
  LC_COLLATE
  LC_MONETARY
  LC_MESSAGES
  LC_IDENTIFICATION
  LC_ALL
  LANGUAGE
  LC_PAPER
  LC_NAME
  LC_ADDRESS
  LC_TELEPHONE
  LC_MEASUREMENT
}

default['scale_ssh'] = {
  'keys' => {},
  'sshd_config' => {
    'AcceptEnv' => accept_env,
    'AuthorizedKeysFile' => '/etc/ssh/authorized_keys/%u',
    'ChallengeResponseAuthentication' => false,
    'GSSAPIAuthentication' => false,
    'GSSAPICleanupCredentials' => false,
    'HostKey' => %w{
      /etc/ssh/ssh_host_ecdsa_key
      /etc/ssh/ssh_host_ed25519_key
      /etc/ssh/ssh_host_rsa_key
    },
     'PasswordAuthentication' => false,
     'Subsystem' => 'sftp /usr/libexec/openssh/sftp-server',
     'SyslogFacility' => 'AUTHPRIV',
     'UseDNS' => false,
     'UsePAM' => true,
     'UsePrivilegeSeparation' => 'sandbox',
     'X11Forwarding' => true,
  },
}
