def self.test_remote_client_rb_extra_code(_hostname)
  <<~EOF

    follow_client_key_symlink true
    client_fork false
    no_lazy_load false
    local_key_generation true
  EOF
end
