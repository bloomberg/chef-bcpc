#!/usr/bin/env bash

set -ex

readonly DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
readonly PROGNAME="$(basename "$0")"

# bash imports
source ./virtualbox_env.sh

usage () {
    cat <<- EOF
usage: $PROGNAME ssh_config

Examples:
    $PROGNAME .cache/dev/ssh_config
EOF
}

# check parameters
if [[ "$#" -ne 1 ]]; then
  usage
  exit 1
fi

readonly SSH_CONFIG="$1"
if [[ -z "$SSH_CONFIG" ]]; then
  echo "$SSH_CONFIG does not exist."
  exit 1
fi

readonly SSH_CMD="ssh -F $SSH_CONFIG -t bcpc-bootstrap"
readonly KEYFILE=bootstrap_chef.id_rsa

readonly subnet=10.0.100
node=11
for i in bcpc-vm1 bcpc-vm2 bcpc-vm3; do
  MAC=`$VBM showvminfo --machinereadable $i | grep macaddress1 | cut -d \" -f 2 | sed 's/.\{2\}/&:/g;s/:$//'`
  if [ -z "$MAC" ]; then
    echo "***ERROR: Unable to get MAC address for $i"
    exit 1
  fi

  echo "Registering $i with $MAC for ${subnet}.${node}"
  $SSH_CMD "sudo cobbler system remove --name=$i; sudo cobbler system add --name=$i --hostname=$i --profile=bcpc_host --ip-address=${subnet}.${node} --mac=${MAC}"
  let node=node+1
done

$SSH_CMD "sudo cobbler sync"
