#
# Cookbook Name:: scale_users
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

admins = {
  'dcavalca' => '1001',
  'phil' => '1002',
  'bwann' => '1003',
  'ilan' => '1004',
  'bala' => '1005',
  'jhoblitt' => '1006',
  'ron' => '1007',
  'leiz' => '1008'
}

admins.each do |user, uid|
  user user do
    uid uid
    group 'users'
    home "/home/#{user}"
    manage_home true
    shell '/bin/bash'
  end
end

group 'sudo' do
  members admins.keys
  system true
  gid 101
end

node.default['scale_sudo']['users']['%sudo'] = 'ALL=NOPASSWD: ALL'

node.default['scale_ssh']['keys']['dcavalca'] = [
  'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAyn0jNSc2AeYCjb90p3moeKTrNccFQLAgT5xIRrNqE+WdO0s23PccPmNAWQe6ymQVttfxPdL7w6kkl0nJeC+4YV5p/5l4AaaxKEVGds+UOxmsYVg7Ae5+P71bg+gsn0Im2TWCG6s18gyhHtiuoqo0Lm9JW9vgdYRA/5aIwNAcSDcRr2M8LLyxDxIHajN1hoFVH1bwPGF7M6wmf5+eEN7Zi2A9qsdlOul7FubrJ5zuX/i++8w+DITFY/SBTQKNU+PSqDfcmmBftEVymwylqWkwJVeTDlDse1QDRF9AES1JdE0nMwIjTsluZiUAXvQaFUJv6CjLgUaMri/00X38apOLhw== davide@sfera',
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDuNC+fuT8z8xrpMTg9z+RMgqDqquHN40ejlS87bOYAawEABIixAJzsHGcCbmuYcbJQReFnYR5RgPU0D+3oSbAdiBD1Xdk1ao8R1jmKWFYtVIapagfKTjb4XCuqlH7BItzJBtgMncO3bNsLg4fzwm9EZKPBsi3oJmgkeG6X3Ru3AcjgHvOqwuCEbwfPvriwCbiheWYZkPJ9NeFIxQ9K/cjHj0/fgoU6jTKW1ajw5B8TYugfVagSogoAzNhji/lmAdop3hihV8l7uYMfd7pGNMS1J9TwK5hl3lKA152E5/mug8pw4iZGKOJTl8q09JXwaaXKtGkYrOatUvr+7Rkltroj dcavalca@tardis',
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSaJzveo5JrJQnkHUtMoxDaxVWgdFk11MElVR5saPWA5WFZJA26vkd9RAaiGuHvBlIl0FsX+VhmJNS7DKHB9EswDXYz39SN9+DqLB7RlX6hKE6Vs1ehi87dh0VRVTygLgDAyuWD/Rxp920lQtN7tUJ44O1go/A/os7u8Q0En0ivZsxzdwwccqEodGiXx9mhtrsl5Z3uFhrZXrfMRKV742khXe9kt68Uj+OeWnE0CIH2dWBiC2Y0Mi5DLp4Pu/TcT/wl0gDAtvDtXDVG4RoBfQxMbIrz5P4KClxJJ612pXdVmcVw8EyObRIDaEbsvyoiA0a1O2dMv/sZWzO/6Q/l9HR dcavalca@tardis',
]
node.default['scale_ssh']['keys']['phil'] = [
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/4f1jzzMrKtRv3VrikBIA5INrW94iHlKD7+4Iq/yGhMMI19eqz987j/9FWZ+X7UrYGbQ22vBSUDSbTGlYBF5H6mXYeEBHPPrp5CVkRNTi6QxNwGuqsh4gsKHLuUJNNHsyOsB1JO49K/sF897e2XvfmitAxKszL1H1PkJ2vvtajeaauIwq8AmJvUNsRwUXBVxzUtKMbfTAtGmTjQWi/U1Yy7G6UV2UTgQjn0dB/R000tO6ghPGEtUAf+GJPj5iKYKR4UAeuB76+BTzxSkK1uFoh0FPQqqO30NjYMWf9qI7+KjU5kvPA995aRDTBPOa1zp/LUpfaJQrmV26T91Rh0RVScL/A+HawZMqpiGrRM/2QBU2id/IFBQje+AHGjq6ZI8R44lKBkw1884BUPofblYt8TPatcX3Evlm+Od9CpDgvlK0BFxMSHG6jcDU+BQY6o23uSYSYehl05hG/M4La5jv/2CIaaCLdySi9/DW5r8iee4fi8j7Q+GI+eUOWwxKBk1/VwYqodk9nnb+TtdiE2aOuJHEPkYDsLXj5ITav4KPYxNUh4mvWs6m3EC0zSHRu9g7GfRAKLBlBzlyHxCZ8/VP9jh8Jj1tyWJbAc16WkXbcjf3yNrbtwUpvShBYw4H11evEwTk6S2RB5aGL7LVE/+xmo27xbnPUIkZhBzclCykdw== phil@ipom.com 2/18/16'
]

node.default['scale_ssh']['keys']['ilan'] = [
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCbsmmelU0LNMncpMV7Gwv00e7CO8f/A8ZPKFGSko86+na6iLXmbvdPYp4b/h3cnHRyex/gPzW8uyzGVE5aJZQXCDnA1GyoYtKfCjkVmPGWV4qt+3qMUwhxaFfgnxbyUI+ETWVi1gaPOJsB71YEAm1y9LdVZ1rKwWQQb5jNBNHTHSdbUqUEVacoGl6ZMtGPlwR0dgMOI3nLpspBmBn3Y8DY7FE7vbYQncECsOPQphS5vVNgj7ksNjHMKLcV06rH2E4NRiEUjRQPetSQymldtbk+HZzuB50wM+Kg83cS/dCxzj8SQJ6ELc9rZg/x1oalUHiRlPD48BTR7opmCJDiqIbR'
]

node.default['scale_ssh']['keys']['bala'] = [
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDE2slzn7hC4jtnLQmiIIHWr4Qb6DqI4sqk1RPJEtcTmZiihdAzraBkdjsG2ARR4EyfGws3LXrc+3ZIiHJjUttpYiTY7T9GvZ9cpTOz5sC+88FIDIb2t1+FMiCExq7Pdg0p7Sq1erSFkwqSbEI43O3c2PXyPXVzdh4YjimOU1hfaqbZ3YtiotRPU9H56yqOzg/GLFnIj6mED9skZt7O7/gqPZaEiRfy8dXEVx2J2X70LAAcMb+3bQyu2cTeKULMWIhW757hSZcu5WL3H4o7UQhw87pr/qtTwINpY/O571nPieuQPvLS9MS72PihR8mJ4P5TnT/CBGdWxVP9xGOAm2y7 hriday@Hridays-Air'
]

node.default['scale_ssh']['keys']['jhoblitt'] = [
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCSktxAqLJWTUX63vNrJKyyJWxgtO/3DmRPy7KqDlLko+NAGvk2boc0KkZpD44aPsBxfZnl5gKuRQXb71gMoHk7qF5XsT/DTHxadhtWTSZiHfhZJ4CrkHuiu/8HGUbp5ENrIYIqhyhN5PydJyEW5NfPvRg7n2O5XXZENq+KtxMqBujuXzm9HOese8FTck3nlUnkqz3ObNRyeOCqIXPNukpRDSNRrFY7D8P2Y1/QLeixPzXd6pMkra9gnOPjrs/X9z2lGRaiyhMrraPtBWMlgf2dnN/PjC38T8vC0/xZq0P1N9G5n0swNe961Xr74/gsFvoh004A1aerWhcFnk1+yf79 jhoblitt@cpan.org'
]

node.default['scale_ssh']['keys']['ron'] = [
  'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAwfPsFGX4aLsFSCYYtzIvxF0vmvf0+EJ4kWZGDzUPBhJEhVzeTLw60Y9q3Nv9ApktpiELL0rsYKYLAQkycO9feB7wG6IUsBTPLbumb4hF9V0MXpOUPewluM5qOw5YRa64j0KYrPMwbcP4sA2tOCgs9rP4mSOeIBXPh7bHFM6ryzSuri0ZCC2uEx0hE9MvBWnkL6B2GUnUAFLDkjc46QO44oshr3ejAqn8eyMX/09eSDcsbLv6aix5eFpnxwYQXkjZ6ZcEpVx61/17+GOM5vRiAt+svQW0BH+Ss0AW+t5TAwqsRLrz/q8SZDbtgbarzPqS/I82YLKbSw9Lp8axRPmVUw== rgolan@tabu'
]

node.default['scale_ssh']['keys']['leiz'] = [
  'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAv0JJzVcYGxpCJ7FqnCvr2LjY0fSC0Ehwb4vuU2CsO50h9M+1br1tQoxWM2ynHle71OLTuvaoBPB1D7FlcyMcvL9DoSjJVXezPYlyrdup9obX17svGaA8VE4x8hyD9PXPwVs8x9hAmF4cCC28nDu/WMY3MfEkT8yFghsl4hBEGlTKUIYiG17Xf5Ty3jfcsaJrqhsGbcqlt5FN9+ytDFpLY0pB+0IDQAAlq/e5RoeE9xh7s+XIzZOl3cnAiFOhyUHvvEIWPTaeNf5unGQk4CRjvre4+dID+sJP8ORCANhHxtH8iH9jixQQLQQEuK6aGxS2okwxIiEvmUCNY105H4oDoQ== thestig@flea'
]
