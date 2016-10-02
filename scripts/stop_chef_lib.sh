#!/bin/bash

CHEF_CURRENT_OUT='/var/chef/outputs/chef.cur.out'
SKIP_SELF=0
PS="ps -e -o pid,pgid,sess,command"

get_chefctl_procs() {
  out=$($PS | grep -v chefctl_solo | grep chefctl)
  if [ "$SKIP_SELF" -eq 1 ]; then
    pgid=$($PS | grep $$ | awk '{print $2}' | uniq)
    out=$(echo "$out" | grep -v "$pgid")
  fi
  echo "$out" | awk '{print $1}' | xargs
}

get_chefclient_procs() {
  opts=''
  if [ "$OS" = 'Darwin' ]; then
    opts='-f'
  fi
  pgrep $opts chef-client
}

stop_or_wait_for_chef() {
  [ "$1" = 'skip_self' ] && SKIP_SELF=1

  # Is Chef even running?
  [ -z "$(get_chefctl_procs)" ] && return 0

  if [ ! -e $CHEF_CURRENT_OUT ]; then
    return 0
  fi

  # If it is running ...
  # If there is only one line, then we are in the "sleep for $splay"
  # phase (the first line is printed by client.rb), so it's safe to kill it.
  # There's a VERY VERY slight race condition here in that we could look at the
  # file and then the splay ends and it starts, but it takes more than a second
  # for authentication and synchronization to happen, so even if that happens,
  # we will kill the run before it's done anything useful.

  # If "skip_self" flag is passed we take care to kill *other* chefctl runs
  # or properly wait for them to finish.

  lines=$(wc -l $CHEF_CURRENT_OUT | awk '{print $1}')
  procs=$(get_chefctl_procs)
  if [ "$lines" -lt 3 ] ; then
    if [ -n "$procs" ]; then
      kill $procs 2> /dev/null
      sleep 1
      kill $procs 2> /dev/null
      kill -9 $procs 2> /dev/null
    fi
    pkill chef-client 2> /dev/null
    sleep 1
    pkill -9 chef-client 2> /dev/null
  else
    num_chefctl_procs=$(echo "$procs" | wc -w)
    # Each chefctl instance can show up as 1-3 processes. So best case, we'll
    # only queue 5 runs. Worst case, we'll queue 15 runs.
    if [ "$num_chefctl_procs" -lt 15 ] ; then
      echo -n 'Waiting for other Chef runs to complete '
      while true; do
        [ -z "$(get_chefclient_procs)" ] && break
        echo -n '.'
        sleep 5
      done
      # chef-client is gone, kill any left waiting chefctls
      procs=$(get_chefctl_procs)
      if [ -n "$procs" ]; then
        kill $(get_chefctl_procs) >/dev/null 2>/dev/null
      fi
      echo ' done.'
    else
      echo 'Several Chef runs already queued. Not queueing any more.'
      exit 0
    fi
  fi
  return 0
}
