#!/bin/bash

set -u

RUNLIST_FILE='/etc/chef/runlist.json'
CHEF_PROD_CONFIG='/etc/chef/client-prod.rb'
ROLE=$(hostname -s | cut -f 2 -d- | sed -E 's/[0-9]+$//g')
CHEFDIR='/var/chef'
REPODIR="$CHEFDIR/repo"
OUTPUTS="/var/log/chef"

bootstrap() {
  [ -x /bin/wget ] || yum install -y wget
  if [ ! -d /opt/cinc ]; then
    mkdir -p /etc/chef $CHEFDIR $REPODIR $OUTPUTS
    wget -qO- 'https://omnitruck.cinc.sh/install.sh' | bash
  fi
  ln -sf /etc/chef /etc/cinc
  cat > $CHEF_PROD_CONFIG <<EOF
cookbook_path [
  '/var/chef/repo/cookbooks',
]
role_path '/var/chef/repo/roles'
ohai.optional_plugins ||= []
ohai.optional_plugins += [:shard]
follow_client_key_symlink true
client_fork false
no_lazy_load false
local_key_generation true
local_mode true
json_attribs '$RUNLIST_FILE'
EOF

  for key in client-prod validation; do
      file="/etc/chef/$key.pem"
      if ! [ -e "$file" ]; then
          # Key isn't used in local mode, so no specific options
          # are really necessary
          openssl genrsa -out "$file"
      fi
  done

  ln -sf /etc/chef/client-prod.rb /etc/chef/client.rb
  ln -sf /etc/chef/client-prod.pem /etc/chef/client.pem
  cp $REPODIR/cookbooks/scale_chef_client/files/default/chefctl_hooks.rb /etc/chef
  cp $REPODIR/cookbooks/scale_chef_client/files/default/chefctl-config.rb /etc/

  cat >$RUNLIST_FILE <<EOF
{"run_list":["recipe[fb_init]","role[$ROLE]"]}
EOF
  [ -x /bin/git ] || yum install -y git
}

if [ "$EUID" -ne 0 ]; then
    echo "Ray, when somebody asks you if you're a god, you say YES!"
    echo "(run this as root)"
    exit 1
fi

if ! [ -d "$REPODIR" ]; then
    echo "Please make /var/chef/repo a git clone of the scale-chef repo"
    exit 1
fi

bootstrap
