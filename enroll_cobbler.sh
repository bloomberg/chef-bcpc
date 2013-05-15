#!/bin/bash

set -e

DIR=`dirname $0`/vbox

pushd $DIR

KEYFILE=bootstrap_chef.id_rsa

subnet=10.0.100
node=11
for i in bcpc-vm1 bcpc-vm2 bcpc-vm3; do
  MAC=`VBoxManage showvminfo --machinereadable $i | grep macaddress1 | cut -d \" -f 2 | sed 's/.\{2\}/&:/g;s/:$//'`
  echo "Registering $i with $MAC for ${subnet}.${node}"
  if hash vagrant; then
    vagrant ssh -c "sudo cobbler system remove --name=$i; sudo cobbler system add --name=$i --hostname=$i --profile=bcpc_host --ip-address=${subnet}.${node} --mac=${MAC}"
  else
    ssh -t -i $KEYFILE root@$1 "cobbler system remove --name=$i; cobbler system add --name=$i --hostname=$i --profile=bcpc_host --ip-address=${subnet}.${node} --mac=${MAC}"
  fi
  let node=node+1
done

if hash vagrant; then
  vagrant ssh -c "sudo cobbler sync"
else
  ssh -t -i $KEYFILE root@$1 "cobbler sync"
fi
