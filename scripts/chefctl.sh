#!/bin/bash

set -u

LOCAL_MODE=1
BOOTSTRAP=0
DEBUG=0
IMMEDIATE=0
HUMAN=0
DEFAULT_SPLAY=600
UPDATE=1
VAGRANT=0
QUIET=0
WHYRUN=0
COLOR=0
SPLAY=''

RUNLIST_FILE='/etc/chef/runlist.json'
CHEF_CONFIG='/etc/chef/client.rb'
CHEF_CLIENT='/usr/bin/chef-client'
CHEF_ARGS="--no-fork -j $RUNLIST_FILE -c $CHEF_CONFIG -F null"
LOCKFILE=/var/lock/subsys/$(basename $0 .sh)
LOCK_FD_OUT="$LOCKFILE"
LOCK_TIMEOUT=1800
STAMPFILE='/etc/chef/test_timestamp'
ROLE=$(hostname -s)
CHEFDIR='/var/chef'
[ -d $CHEFDIR ] || mkdir -p $CHEFDIR
REPODIR="$CHEFDIR/repo"
[ -d $REPODIR ] || mkdir -p $REPODIR
OUTPUTS="$CHEFDIR/outputs"
[ -d $OUTPUTS ] || mkdir -p $OUTPUTS
LASTLINK_OUT=$OUTPUTS/chef.last.out
CURLINK_OUT=$OUTPUTS/chef.cur.out
FIRST_RUN_SAVE=$OUTPUTS/chef.first.out

REPOS='
  https://github.com/socallinuxexpo/scale-chef.git
'

[ -r /var/chef/repo/scale-chef/scripts/stop_chef_lib.sh ] && \
  . /var/chef/repo/scale-chef/scripts/stop_chef_lib.sh


get_repos() {
  for repo in $REPOS; do
    cd $REPODIR
    echo "updating $repo"
    dir=$(basename $repo .git)
    if ! [ -d "$dir" ]; then
      git clone $repo
    fi
    cd $dir
    git pull
    git submodule init
    git submodule update
  done
}

copy_from_vagrant() {
  for d in cookbooks roles scripts; do
    rsync -avz --delete /vagrant/$d/ $REPODIR/scale-chef/$d/
  done
}

bootstrap() {
  [ ! -d /opt/chef ] && \
    wget -qO- 'https://www.opscode.com/chef/install.sh' | bash
  mkdir -p /etc/chef $CHEFDIR $REPODIR $OUTPUTS
  cat > /etc/chef/client-prod.rb <<EOF
cookbook_path [
  '/var/chef/repo/scale-chef/cookbooks',
]
role_path '/var/chef/repo/scale-chef/roles'
EOF
  ln -sf /etc/chef/client-prod.rb /etc/chef/client.rb

  cat >/etc/chef/runlist.json <<EOF
{"run_list":["recipe[fb_init]"]}
EOF
  [ -x /bin/git ] || yum install -y git
  get_repos
}

gen_logdate() {
  date +%Y%m%d.%H%M.%s
}

wait_for_lock() {
  flock -w $LOCK_TIMEOUT -n 200
  lock_acquired=$?
  return $lock_acquired
}

try_lock() {
  flock -n 200
  lock_acquired=$?
  return $lock_acquired
}

obtain_lock() {
  if [ $IMMEDIATE -eq 1 ]; then
    # Kill *other* chefctl instances if they are sleeping
    stop_or_wait_for_chef 'skip_self'
  fi

  try_lock
  lock_acquired=$?
  if [ $lock_acquired -ne 0 ]; then
    message="$LOCKFILE is locked, waiting up to $LOCK_TIMEOUT seconds."
    warn "$message"
    wait_for_lock
    lock_acquired=$?

    if [ $lock_acquired -ne 0 ]; then
      message="Unable to lock $LOCKFILE"
      warn "$message"
      exit 1
    fi
  fi
}

_run() {
  extra_args="$1"
  log="$2"
  if [ "$DEBUG" -eq 1 ]; then
    extra_args="-l debug $extra_args"
  elif [ "$HUMAN" -eq 1 ]; then
    extra_args="-l fatal -F doc $extra_args"
  fi

  if [ "$LOCAL_MODE" -eq 1 ]; then
    extra_args="-z $extra_args"
  fi

  if [ "$WHYRUN" -eq 1 ]; then
    extra_args="--why-run $extra_args"
  fi

  if [ "$COLOR" -eq 0 ]; then
    extra_args="--no-color $extra_args"
  fi

  cmd="$CHEF_CLIENT $CHEF_ARGS $extra_args"
  if [ "$DEBUG" -eq 1 ]; then
    echo "Running: $cmd"
  fi
  (
    [ "$SPLAY" -gt 0 ] && sleep $(($RANDOM % $SPLAY))
    if [ "$QUIET" -eq 1 ]; then
      $cmd >>$log 2>&1
    else
      # we need the real return status
      set -o pipefail
      $cmd 2>&1 | tee -a $log
    fi
    # don't leak fd200 -- otherwise if chef-client starts a daemon, it could
    # have ended up holding the lock forever.
  ) 200< /dev/null 200> /dev/null
}

_keeptesting() {
  now=$(date +%s)
  stamp=$(stat -c %y $STAMPFILE)
  stamp_time=$(date +%s -d "$stamp")
  touch_opts="-d 'now + 1 hour' $STAMPFILE"
  remaining=$((stamp_time - now))
  if [ 0 -lt $remaining ] && [ $remaining -lt 3600 ]; then
    echo 'chef_test mode ends in < 1 hour, extending back to 1 hour'
    eval "touch $touch_opts"
  fi
}

chef_run() {
  extra_args="$*"

  if [ "$LOCAL_MODE" -eq 1 -a "$UPDATE" = 1 ]; then
    if [ $VAGRANT -eq 1 ]; then
      copy_from_vagrant
    else
      get_repos
    fi
  fi

  cmd="$CHEF_CLIENT $CHEF_ARGS"
  if [ "$DEBUG" -eq 1 ]; then
    echo "Running: $cmd"
  fi

  (
    obtain_lock

    # If this is an immediate run and we're in test mode, check if we should
    # extend the test period.
    if [ $SPLAY -eq 0 ] && [ -f $STAMPFILE ]; then
      _keeptesting
    fi

    logdate=$(gen_logdate)
    out=$OUTPUTS/chef.$logdate.out

    touch $out
    ln -sf $out $CURLINK_OUT

    _run "$extra_args" "$out"
    retval=$?

    ln -sf $out $LASTLINK_OUT

    # if we are the first run, save the output
    if [ ! -e $FIRST_RUN_SAVE ]; then
      num_outs=$(ls $OUTPUTS/chef.2* | wc -l)
      if [ "$num_outs" -eq 1 ]; then
        cp $out $FIRST_RUN_SAVE
      fi
    fi
    exit $retval

  ) 200> $LOCK_FD_OUT
  retval=$?
}

longopts='bootstrap,debug,color,help,immediate,why-run,noupdate,quiet,splay:,human,vagrant'
shortopts='bdchHinuqs:uV'

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
    --color|-c)
      COLOR=1
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
    --why-run|-n)
      WHYRUN=1
      HUMAN=1
      shift
      ;;
    --noupdate|-u)
      UPDATE=0
      shift
      ;;
    --quiet|-q)
      QUIET=1
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

grep -q 'taste-tester' /etc/chef/client.rb
ret=$?
if [ $ret -eq 0 ]; then
  LOCAL_MODE=0
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
