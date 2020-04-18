#!/bin/bash

set -u

BOOTSTRAP=0
RUNLIST_FILE='/etc/chef/runlist.json'
CHEF_CONFIG='/etc/chef/client.rb'
CHEF_PROD_CONFIG='/etc/chef/client.rb'
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
  cat > /etc/chef/client-prod.rb <<EOF
cookbook_path [
  '/var/chef/repo/scale-chef/cookbooks',
]
role_path '/var/chef/repo/scale-chef/roles'
EOF
  ln -sf /etc/chef/client-prod.rb /etc/chef/client.rb
  ln -sf /etc/chef/client-prod.pem /etc/chef/client.pem
  cp $REPODIR/cookbooks/scale_chef/files/default/chefctl_hooks.rb /etc/chef
  cp $REPODIR/cookbooks/scale_chef/files/default/chefctl-config.rb /et/

  cat >$RUNLIST_FILE <<EOF
{"run_list":["recipe[fb_init]","role[$ROLE]"]}
EOF
  [ -x /bin/git ] || yum install -y git
}

bootstrap
