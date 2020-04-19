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
  [ ! -d /opt/cinc ] && \
    wget -qO- 'https://omnitruck.cinc.sh/install.sh' | bash
  mkdir -p /etc/chef $CHEFDIR $REPODIR $OUTPUTS
  ln -sf /etc/chef /etc/cinc
  cat > $CHEF_PROD_CONFIG <<EOF
cookbook_path [
  '/var/chef/repo/cookbooks',
]
role_path '/var/chef/repo/roles'
local_mode true
EOF

  ln -sf /etc/chef/client-prod.rb /etc/chef/client.rb
  ln -sf /etc/chef/client-prod.pem /etc/chef/client.pem
  cp $REPODIR/cookbooks/scale_chef_client/files/default/chefctl_hooks.rb /etc/chef
  cp $REPODIR/cookbooks/scale_chef_client/files/default/chefctl-config.rb /etc/

  cat >$RUNLIST_FILE <<EOF
{"run_list":["recipe[fb_init]","role[$ROLE]"]}
EOF
  [ -x /bin/git ] || yum install -y git
}

bootstrap
