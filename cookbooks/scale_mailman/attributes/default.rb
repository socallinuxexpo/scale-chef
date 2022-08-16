# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

d = {}
if File.exists?('/etc/lists_secrets')
  File.read('/etc/lists_secrets').each_line do |line|
    k, v = line.strip.split(/\s*=\s*/)
    d[k.downcase] = v
  end
end

default['scale_mailman'] = {
  's3_aws_access_key_id' =>
    d['s3_aws_access_key_id'] || 'thisisadevkey',
  's3_aws_secret_access_key' =>
    d['s3_aws_secret_access_key'] || 'thisisadevsecret',
  'listmaster' => "ilan@linuxfests.org,listmaster@linuxfests.org",
  'lists' => [
    "board",
    "hilton-tech",
    "linuxfests",
    "mailman",
    "open-infra-day",
    "ossie-planning",
    "pcc-scale-tech",
    "scale-av",
    "scale-cfp-reviewers",
    "scale-chairs",
    "scale-community",
    "scale-design",
    "scale-infra",
    "scale-kids",
    "scale-planning",
    "scale-pr",
    "scale-training",
    "scale-volunteers",
    "scale-webdev",
    "seagl",
    "tech",
    "transportation",
  ],
}
