#!/bin/bash

CHEFDIR='/var/chef'
[ -d $CHEFDIR ] || mkdir -p $CHEFDIR
COOKBOOKDIR="$CHEFDIR/cookbooks"
[ -d $COOKBOOKDIR ] || mkdir -p $COOKBOOKDIR

REPOS='
  https://github.com/facebook/chef-cookbooks.git
  git@github.com:socallinuxexpo/scale-chef.git
'

get_cookbooks() {
  for repo in $REPOS; do
    cd $COOKBOOKDIR
    echo "updating $repo"
    dir=$(basename $repo .git)
    if [ -d "$dir" ]; then
      cd $dir
      git pull
    else
      git clone $repo
    fi
  done

}

get_cookbooks

# todo: abstract out roles
chef-client -z -c /etc/chef/client.rb -o 'fb_init,scale_apache'
