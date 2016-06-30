# See http://docs.chef.io/config_rb_knife.html for more information on knife configuration options

current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "linuxfests"
client_key               "#{current_dir}/linuxfests.pem"
validation_client_name   "linuxfests-validator"
validation_key           "#{current_dir}/linuxfests-validator.pem"
chef_server_url          "https://api.chef.io/organizations/linuxfests"
cookbook_path            ["#{current_dir}/../cookbooks", "#{current_dir}/../fb-cookbooks/cookbooks"]
