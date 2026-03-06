#
# Cookbook:: ci_fixes
# Recipe:: default
#
# Copyright:: 2026, The Authors, All Rights Reserved.
#

# logind doesn't work in the CI containers
node.default['fb_systemd']['logind']['enable'] = false

# older versions of rsyslog try to call close() on every _possible_ fd
# as limited by ulimit -n, which can take MINUTES to start. So drop this
# number for CI: https://github.com/rsyslog/rsyslog/issues/5158
# TODO: Use fedora_derived?
if fedora_derived?
  node.default['fb_limits']['*']['nofile'] = {
    'hard' => '1024',
    'soft' => '1024',
  }
end

# postfix hasn't setup it's chroot on rsyslog's first startup and
# thus it fails in containers on firstboot, so override postfix
# telling syslog to look at its socket.
whyrun_safe_ruby_block 'ci fix for postfix/syslog' do
  # TODO: Use fedora_derived?
  only_if { fedora_derived? }
  block do
    node.default['fb_syslog']['rsyslog_additional_sockets'] = []
  end
end

# GH Runner's forced apparmor doesn't let binaries write to
# /run/systemd/notify, so tell the unit not to try
fb_systemd_override 'syslog-no-systemd' do
  # TODO: Use fedora_derived?
  only_if { fedora_derived? }
  unit_name 'rsyslog.service'
  content({
            'Service' => {
              'Type' => 'simple',
            },
          })
end
