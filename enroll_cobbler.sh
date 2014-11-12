#!/bin/bash

set -e

# bash imports
source ./virtualbox_env.sh

if ! hash vagrant 2>/dev/null; then
    if [[ -z "$1" ]]; then
	# only if vagrant not available do we need the param
	echo "Usage: $0 <bootstrap node ip address>"
	exit
    fi
fi

if [ -f ./proxy_setup.sh ]; then
  . ./proxy_setup.sh
fi

if [ -z "$CURL" ]; then
	echo "CURL is not defined"
	exit
fi

DIR=`dirname $0`/vbox

pushd $DIR

KEYFILE=bootstrap_chef.id_rsa

subnet=10.0.100
node=11
SSHCOMMON="-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o VerifyHostKeyDNS=no"
SSHCMD="ssh $SSHCOMMON"
for i in bcpc-vm1 bcpc-vm2 bcpc-vm3; do
  MAC=`$VBM showvminfo --machinereadable $i | grep macaddress1 | cut -d \" -f 2 | sed 's/.\{2\}/&:/g;s/:$//'`
  if [ -z "$MAC" ]; then 
    echo "***ERROR: Unable to get MAC address for $i"
    exit 1 
  fi 
  echo "Registering $i with $MAC for ${subnet}.${node}"
  REGISTERCMD="sudo cobbler system remove --name=$i; sudo cobbler system add --name=$i --hostname=$i --profile=bcpc_host --ip-address=${subnet}.${node} --mac=${MAC}"
  if hash vagrant 2>/dev/null; then
    vagrant ssh -c "$REGISTERCMD"
  else
      if hash sshpass 2>/dev/null; then
	  echo ubuntu | sshpass -p ubuntu $SSHCMD -tt ubuntu@$1 "$REGISTERCMD"
      else
	  ssh -t -i $KEYFILE ubuntu@$1 $REGISTERCMD
      fi
  fi
  let node=node+1
done

SYNCCMD="sudo cobbler sync"
if hash vagrant 2>/dev/null; then
  vagrant ssh -c "$SYNCCMD"
else
  if hash sshpass 2>/dev/null; then
      echo ubuntu | sshpass -p ubuntu $SSHCMD -tt ubuntu@$1 "$SYNCCMD"
  else
      ssh -t -i $KEYFILE ubuntu@$1 "$SYNCCMD"
  fi
fi
