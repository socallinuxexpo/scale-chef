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
  'leiz' => '1008',
  'btmash' => '1009',
  'drupalphil' => '1010',
  'rothgar' => '1011',
  'cbsmith' => '1012',
  'karen' => '1013',
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
  gid node.el_max_version?(8) ? 101 : 1001
end

node.default['fb_sudo']['users']['%sudo']['admins can run anything'] =
  'ALL=NOPASSWD: ALL'

node.default['fb_sudo']['users']['root']['avoid errors when root sudos'] =
  'ALL=NOPASSWD: ALL'

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
  'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAv0JJzVcYGxpCJ7FqnCvr2LjY0fSC0Ehwb4vuU2CsO50h9M+1br1tQoxWM2ynHle71OLTuvaoBPB1D7FlcyMcvL9DoSjJVXezPYlyrdup9obX17svGaA8VE4x8hyD9PXPwVs8x9hAmF4cCC28nDu/WMY3MfEkT8yFghsl4hBEGlTKUIYiG17Xf5Ty3jfcsaJrqhsGbcqlt5FN9+ytDFpLY0pB+0IDQAAlq/e5RoeE9xh7s+XIzZOl3cnAiFOhyUHvvEIWPTaeNf5unGQk4CRjvre4+dID+sJP8ORCANhHxtH8iH9jixQQLQQEuK6aGxS2okwxIiEvmUCNY105H4oDoQ== thestig@flea',
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDZIN2O48j/ngMMhXA2npl8hBA2Az5iYJxB/Q7rMIcQtUcXXeSUAbwEiU7rEcZkPZhK7PCzeo7o5Dd9z+U1Li21rST06Je0CL+TXs38xk/XnnTcHiusflnbM1VZ7yJBAoLWlzicl93owDBqV7H9fau+7rXmI9MoPLV+xqG4sr+qb7UPTfmGSHJVNPtBIODf8+JR7fllbsIY2yH01qc74HLqIZrdgrFa14ExDx+BtF8gHnb0LoZ8hP/BC4kDymJ/wDE2sQBKj6Klyi5ahYWsw5vQNvCf97zHSfweF1jH5TFPsSxdxRYGoxLMUXSlFqPJpOzP6qWCG0NCRGqF5sT65seIWfqHpyrtMsejnOXz+CpHJVJDGsA74GIaPbkbuEISvi0t/0Q557auk59/spYVGaxCkiTuTKqUcocP3Gyizf+s6G+4Jbtm1RpdxR52yZL/FoLU2VzJqAQT/knYRv7SV4AQRYuV3FAulS6i8vATYyIjkRm7VsKuns8a8X9DDMx0HDU= leiz',
]

node.default['scale_ssh']['keys']['vikas'] = [
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDczH1kkyzHpfIvhHd1Kh2v5593uC8MKyY3ZlD2ae8ySzUCJ1AaUl2JWJI/P3cONEQAJa4aiGvj9nCvH/QnClgkcjDVAq2Jo6r8CVuyoox4P62X47vdI2dLQzxIAXK0ygXHgXJtxhDBG3yBimXs0q2WGJ4udOLxGygtpksbF81d/9JLbT9XLKAgi2m8G6Za5hw3kYDwR6378/Hw86du4pfE5PCOa6pxRkDXM7dfovBG1VSFVtY+3zjIl0Jy7SiGK5JZBo0Gt/dHnTM/+C+9sXBYXHkUU0mjX5zEIuMUX9W/3A7r/UC6Ojr3JqT1rmy06+SViHstpSBcspIYru3XybfaW9fZEn02D8WY/kW2sNo9I3YIFgGcD37gYVfGqBEWPYEd2Ud+18MniEpa67R71AbdWp374vhP3Te2Hsvfg8TWjEPYZ+NShqrnUIVTK4e7LYDEFwKcaj1a9PBoEeB646HAFmEHZ+8upFRtfybufTPmJm0stArkfrvKLR97faDjLrVsyCTqaE6LpWDckXu930iln1VZkuQB01/jOxPUDc6q+Cx4MbCqDbwRVPi85CU8eM+oNZUoOEv1yv2y82EA7C01BR7PYhuyhwSLy6nHRQH1ZxGjFacNjI8THt2Iohv7WY7pF4TCpJ+pCkHG5DAdMtKnUJV0efMyxdF+qr65Do2EPQ== Vikasrajbhagat@gmail.com'
]

node.default['scale_ssh']['keys']['btmash'] = [
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDjcdNkU4jBgzTtV09P5RjkoOx+S2QBlj0ldAmShCi5DKNW4jrHBSzbNvOeYG25XjKi4lLXGoy/gXi2InhIApHEtnQy+wKhOIFIqPY2bZeBWRF5BW+Jl9R1zI+R7BrpDh6fAQ5R/govHsWKsTP4JqsamN/y/a7bkQpTdEObDQJOY8UVEkJELuQTs8XXQftThaU6RfJGtUcfQtkorsyYCYqEH7v8/X5cPNMyvj/zXBle0yB12nIgoBY6yks2L1NzHXFdhZgnTnHzNrJSkh3jakCC1DtKS4GVGXv9dSl42b5wU86m/VljbFHQzOiu1+8C5dNzCS3uK0jRU8NshqKI+HnEcgDdGBNp3CEqLlTW5iUp1SNfcx/r4l4lR4VFiWFfHexsO8gnvEcRsAMWZPTRq9dv4mnwOucOyrWuu0SJzOb9J3Qh8RU/pw4sPv1WI4xyVkPFRRpB92MzR554incY97bpbaqgqueB5VLnQZ6/INtcGRDFP8MZ8DXcWN3wSC3DTaUFaAswnvrS0t3OgPN2+BoKjBf6vpUcaWfmeDivFr1KxRYAA3EoTXd/ViEPmr7pDyK3cJW9+SW326az9kfBBsvRzhLURziQJoScFVQfQOD8/4azHwqqubQ/CUqZXBjgr3/wFZaBbDQRXuS5kl+epJ/W4kMnEccBDcGxsP4PLsrxhQ== ashokmodi@Ashoks-Mac-mini.local'
]

node.default['scale_ssh']['keys']['drupalphil'] = [
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCliT2cX+9kK80PwBkCDQrQ7B+WCh585cpHnv0TnfNqck1xM+iat3TY1EjvLOaeWJPcZPg/HS9CIIF6DNhAFsImIWVT78tBp1rMxG5vNTfuJkIZdCVL4ZildxTTZNvHxePFA3LXN0qpPyvY3/JVDXo0EKBaieJfT8XRn18++4Z8xnvxXU1xVwQ8vyR3z/CpbTQauA4wXuZUID41GvXXyyu5GzpA96nQy6/w03MWez/8m8BYjSWdfJ1+kADeJOXAAxO27NoKTmWXi+fVCiUNf9WHaYdMxk0VSXXJCUK1/4aETZCbZFG+nrL3cl7klTcobzg2Pgb5RVQd5NtXNBiXQ69iVxFXZ/PPqbd0/Yke3j0CZKlS8AD5/tYIM+pl1SZghMO5Eog2xkw/IMuiqjdu8PQE2uHgC6z9804LIVogYod6ESzzicyNWa5QxxiGpoEZzkn9UOFPObVyyLSWg5dlJ46ov88w7qoh31A+P4Gomq6YYFOP37Za9vhHffqMPMOi9EeToJUjtz3nI1FWt0n9P5bR9uvPgKT5DbCMBDDcA2RuL05fUBUoFLYrW6HiOLvYMpE+YkNF47WGQCk1Ww/xoGVRb6btY/bsYaWEKd2NvHpZoDYQYVrNaCFrY+OX/FTU0/U4SHRBs9+e1CV077mboy1Xe7g1fAM7Tmd/aIMwV3vbzw== drupalphil@macstudio'
]

node.default['scale_ssh']['keys']['rothgar'] = [
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDCn/WYbUnsZCXLPkEhRNBH3wkrkxZGu+sOlVVeqhvsdIRq0E6H8SOglYRJmt/sKgBNt8x+aFkW8rRGUMiGz46XBgx+gGnUBW5WVVPdQ3dKLBLchhyoh6jZc1kFpYpLb+QonWr7ne3FzgyEegUq9qkOcJpDqFJ7IKSlIiPxLb/6ztKRjEhcSHjSBeCYfQddatspaJP2/ei7LV85EsLykAYfIRs/pX0BkuHivC75eOfcs86P9bKnLJm0uWQ62Fkx684fzPPM18AhIEiojkBkluVFSXLI5VxKI58incVMmJ1CBReFg8oqTvSKtQ+rabRX71uGcf0SOM3GCmBJwFUf6noj'
]

node.default['scale_ssh']['keys']['cbsmith'] = [
  'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDa5cJJ4oDpykZcWok0JFzjT95KL4uVPkpFWMSpu3jFohVPZDgZs8bftjZFjFjN3Ly68MHESdZ0Dm2qv3e3DmZYf/j0xpCFeHfi95b+LBYoIgLDQJUKc4LtpXoCjtnGIoek5WYQ/igfHlIGIqyP6XWOvBubM95cub9d4UGYS4v9P4OFS7Xa0WFvYbSOj7xW0yOvQqJQ6seBkLJy/ish/meqo0zdjGsNa/Ct4DQmEM5calXgOid/Ui1xJ5n44jqYizLwFQ9DUQnyMVwxcwJdoWh/ey8m1kyYU+K1mAS/MWuuMNHTAqYP1vs7t/fHHdTc7THTz1ODEOCR6K6AtdtfVW7RgHunFH+iO5I1qNvS3ZuDHP8vvLRiTcJg4pbIdJUssxvTG1JWhEZBnLp3UrKkRfcBQiqq3q4IyOtQPHSnrRQminN9go0WpOkM9WzzlcF/yshDLGegO8OoAElJzMYm50gWzKGWUy2c3K0GcJEAMW1OHCW8l9xTDaolBPJ1swEhF9c= cbsmith@penguin'
]

node.default['scale_ssh']['keys']['karen'] = [
  'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG3tfvvDtFh0I37XSJ0KA6bYzjW38XfOD2I2dfFvK7KJ kaquintanilla@UR-17VQ05N-LT'
]
