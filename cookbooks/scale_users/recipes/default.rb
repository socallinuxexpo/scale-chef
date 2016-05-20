#
# Cookbook Name:: scale_users
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

{
  'dcavalca' => '1001',
  'phild' => '1002',
  'bwann' => '1003',
}.each do |user, uid|
  user user do
    uid uid
    group 'users'
    home "/home/#{user}"
    manage_home true
    shell '/bin/bash'
  end
end

node.default['scale_ssh']['keys']['dcavalca'] = [
  'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAyn0jNSc2AeYCjb90p3moeKTrNccFQLAgT5xIRrNqE+WdO0s23PccPmNAWQe6ymQVttfxPdL7w6kkl0nJeC+4YV5p/5l4AaaxKEVGds+UOxmsYVg7Ae5+P71bg+gsn0Im2TWCG6s18gyhHtiuoqo0Lm9JW9vgdYRA/5aIwNAcSDcRr2M8LLyxDxIHajN1hoFVH1bwPGF7M6wmf5+eEN7Zi2A9qsdlOul7FubrJ5zuX/i++8w+DITFY/SBTQKNU+PSqDfcmmBftEVymwylqWkwJVeTDlDse1QDRF9AES1JdE0nMwIjTsluZiUAXvQaFUJv6CjLgUaMri/00X38apOLhw== davide@sfera',
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDuNC+fuT8z8xrpMTg9z+RMgqDqquHN40ejlS87bOYAawEABIixAJzsHGcCbmuYcbJQReFnYR5RgPU0D+3oSbAdiBD1Xdk1ao8R1jmKWFYtVIapagfKTjb4XCuqlH7BItzJBtgMncO3bNsLg4fzwm9EZKPBsi3oJmgkeG6X3Ru3AcjgHvOqwuCEbwfPvriwCbiheWYZkPJ9NeFIxQ9K/cjHj0/fgoU6jTKW1ajw5B8TYugfVagSogoAzNhji/lmAdop3hihV8l7uYMfd7pGNMS1J9TwK5hl3lKA152E5/mug8pw4iZGKOJTl8q09JXwaaXKtGkYrOatUvr+7Rkltroj dcavalca@tardis',
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSaJzveo5JrJQnkHUtMoxDaxVWgdFk11MElVR5saPWA5WFZJA26vkd9RAaiGuHvBlIl0FsX+VhmJNS7DKHB9EswDXYz39SN9+DqLB7RlX6hKE6Vs1ehi87dh0VRVTygLgDAyuWD/Rxp920lQtN7tUJ44O1go/A/os7u8Q0En0ivZsxzdwwccqEodGiXx9mhtrsl5Z3uFhrZXrfMRKV742khXe9kt68Uj+OeWnE0CIH2dWBiC2Y0Mi5DLp4Pu/TcT/wl0gDAtvDtXDVG4RoBfQxMbIrz5P4KClxJJ612pXdVmcVw8EyObRIDaEbsvyoiA0a1O2dMv/sZWzO/6Q/l9HR dcavalca@tardis',
]
