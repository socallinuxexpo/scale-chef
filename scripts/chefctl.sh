#!/bin/bash

BOOTSTRAP=0
DEBUG=0
IMMEDIATE=0
HUMAN=0
DEFAULT_SPLAY=600
UPDATE=1
VAGRANT=0

ROLE=$(hostname -s)
CHEFDIR='/var/chef'
[ -d $CHEFDIR ] || mkdir -p $CHEFDIR
REPODIR="$CHEFDIR/repo"
[ -d $REPODIR ] || mkdir -p $REPODIR

REPOS='
  https://github.com/facebook/chef-cookbooks.git
  git@github.com:socallinuxexpo/scale-chef.git
'

get_repos() {
  for repo in $REPOS; do
    cd $REPODIR
    echo "updating $repo"
    dir=$(basename $repo .git)
    if [ -d "$dir" ]; then
      cd $dir
      git pull
      git submodule init
      git submodule update
    else
      git clone $repo
      git submodule init
      git submodule update
    fi
  done
}

copy_from_vagrant() {
  rsync -avz --delete /vagrant/cookbooks/ $REPODIR/scale-chef/cookbooks/
}

bootstrap() {
  [ ! -d /opt/chef ] && \
    wget -qO- 'https://www.opscode.com/chef/install.sh' | bash
  mkdir -p /etc/chef $CHEFDIR $REPODIR
  cat > /etc/chef/client.rb <<EOF
cookbook_path [
  '/var/chef/repo/chef-cookbooks/cookbooks',
  '/var/chef/repo/scale-chef/cookbooks',
]
role_path '/var/chef/repo/scale-chef/roles'
EOF

  cat >/etc/chef/runlist.json <<EOF
{"run_list":["recipe[fb_init]"]}
EOF
  [ -x /bin/git ] || yum install -y git
  get_repos
}

chef_run() {
  extra_args="$*"

  sleep $SPLAY
  if [ "$UPDATE" = 1 ]; then
    if [ $VAGRANT -eq 1 ]; then
      copy_from_vagrant
    else
      get_repos
    fi
  fi
  chef-client --no-fork -z -c /etc/chef/client.rb \
    -j /etc/chef/runlist.json $extra_args
}

longopts='bootstrap,debug,help,immediate,noupdate,splay:,human,vagrant'
shortopts='bdhHis:uV'

opts=$(getopt -l $longopts -o $shortopts -- "$@")
if [ $? -ne 0 ]; then
  echo 'Failed to parse options'
  exit 1
fi

eval set -- "$opts"

while true; do
  case "$1" in
    --bootstrap|-b)
      BOOTSTRAP=1
      shift
      ;;
    --debug|-d)
      DEBUG=1
      shift
      ;;
    --vagrant|-V)
      VAGRANT=1
      shift
      ;;
    --human|-H)
      HUMAN=1
      shift
      ;;
    --immediate|-i)
      IMMEDIATE=1
      shift
      ;;
    --noupdate|-u)
      UPDATE=0
      shift
      ;;
    --splay|-s)
      SPLAY="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
  esac
done

if [ "$BOOTSTRAP" = 1 ]; then
  echo "Bootstrapping node"
  bootstrap
  exit 0
fi

extra_chef_args="$*"

# Splay and Immediate are mutually exclusive so work that out
if [ -z "$SPLAY" ]; then
  # No splay passed so respect immediate or default
  if [ $IMMEDIATE -eq 1 ]; then
    SPLAY=0
  else
    SPLAY=$DEFAULT_SPLAY
  fi
else
  # Splay was passed so use it or error on nonsense
  if [ $IMMEDIATE -eq 1 ]; then
    echo -n 'Splay and Immediate options are mutually exclusive. You ' >&2
    echo 'passed both. Try again.' >&2
    exit 1
  fi
  # if we get here, the splay is whatever was passed
fi

chef_run "$extra_chef_args"
