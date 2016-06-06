# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

d = {}
if File.exists?('/etc/lists_secrets')
  File.read('/etc/lists_secrets').each_line do |line|
    k, v = line.strip.split(/\s*=\s*/)
    d[k.downcase] = v
  end
end

default['scale_mailman'] = {
  's3_aws_access_key_id' => d['s3_aws_access_key_id'] || 'thisisadevkey',
  's3_aws_secret_access_key' => d['s3_aws_secret_access_key'] || 'thisisadevsecret',
}

default['scale_mailman']['listmaster'] = "ilan@linuxfests.org"

default['scale_mailman']['lists'] = [
    "board",
    "mailman",
    "scale-av",
    "scale-design",
    "scale-pr",
    "scale-webdev",
    "transportation",
    "hilton-tech",
    "ossie-planning",
    "scale-chairs",
    "scale-kids",
    "scale-training",
    "seagl",
    "linuxfests",
    "pcc-scale-tech",
    "scale-community",
    "scale-planning",
    "scale-volunteers",
    "tech"
]
