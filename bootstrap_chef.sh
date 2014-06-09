#!/usr/bin/env bash

set -ex

readonly DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
readonly PROGNAME="$(basename "$0")"

usage () {
    cat <<- EOF
usage: $PROGNAME ssh_config ip_address chef_environment

Bootstrap the bcpc-bootstrap node as defined in the 'ssh_config' file with
the given 'chef_environment'.  Note that the name to be used must be
'bcpc-bootstrap'.

Examples:
    $PROGNAME .cache/dev/ssh_config Test-Laptop
EOF
}

# check parameters
if [[ "$#" -ne 3 ]]; then
  usage
  exit 1
fi

readonly SSH_CONFIG="$1"
readonly IP="$2"
readonly CHEF_ENVIRONMENT="$3"

if [[ -z "$SSH_CONFIG" ]]; then
  echo "$SSH_CONFIG does not exist."
  exit 1
fi

readonly BCPC_DIR="chef-bcpc"

# protect against rsyncing to the wrong bootstrap node
if [[ ! -f "environments/${CHEF_ENVIRONMENT}.json" ]]; then
    echo "Error: environment file ${CHEF_ENVIRONMENT}.json not found"
    exit
fi

SSH_CMD="ssh -F $SSH_CONFIG"
RSYNC_CMD() {
  rsync $RSYNCEXTRA -avP -e "$SSH_CMD" --exclude .cache --exclude images "$@"
}
RSYNC_CMD --exclude .chef . bcpc-bootstrap:chef-bcpc
RSYNC_CMD .cache/downloads/ubuntu-12.04-mini.iso bcpc-bootstrap:chef-bcpc/cookbooks/bcpc/files/default/bins

SSH_CMD="$SSH_CMD -t bcpc-bootstrap"
echo "Building binaries"
$SSH_CMD "cd $BCPC_DIR && sudo ./cookbooks/bcpc/files/default/build_bins.sh"
echo "Setting up chef server"
$SSH_CMD "cd $BCPC_DIR && sudo ./setup_chef_server.sh ${IP}"
echo "Setting up chef cookbooks"
$SSH_CMD "cd $BCPC_DIR && ./setup_chef_cookbooks.sh ${IP} ${SSH_USER}"
echo "Setting up chef environment, roles, and uploading cookbooks"
$SSH_CMD "cd $BCPC_DIR && knife environment from file environments/${CHEF_ENVIRONMENT}.json && knife role from file roles/*.json && knife cookbook upload -a -o cookbooks"
echo "Enrolling local bootstrap node into chef"
$SSH_CMD "cd $BCPC_DIR && ./setup_chef_bootstrap_node.sh ${IP} ${CHEF_ENVIRONMENT}"
