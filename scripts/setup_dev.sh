#!/bin/bash

if [ $EUID -eq 0 ]; then
    echo "Please do not do this as root" >&2
    exit 1
fi

echo "Checking for CINC version of Chef Workstation"
if ! [ -d /opt/cinc-workstation ]; then
    echo -n "Install the CINC Workstation package for your distro" >&2
    echo -n " from http://downloads.cinc.sh/files/stable/" >&2
    echo " and try again" >&2
    exit 1
fi

echo "Checking for path setup"
if ! echo "$PATH" | grep -q chefdk; then
    echo "You need to setup your shell to use Chef Workstation" >&2
    # shellcheck disable=SC2016
    echo 'Try `eval "$(cinc shell-init SHELL_NAME)"`' >&2
    exit 1
fi

echo "Installing deps"

# If rugged isn't installed with this environment variable setup,
# it work work
export OPENSSL_ROOT_DIR='/opt/cinc-workstation/embedded'
cinc gem install rugged

# now we can install everything else
cinc exec bundle install
