#!/bin/bash

set -e

IP="${1:?"Need the IP of a machine to install"}"
ENVIRONMENT="${2:?"Need the Chef environment to use"}"

echo "initial configuration of $IP"

if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi

load_binary_server_info $ENVIRONMENT
load_chef_server_ip

SCPCMD="./nodescp    $ENVIRONMENT $IP"
SSHCMD="./nodessh.sh $ENVIRONMENT $IP"

echo "copy files..."
for f in zap-ceph-disks.sh install-chef.sh finish-worker.sh finish-head.sh; do
  $SCPCMD $f ubuntu@$IP:/home/ubuntu || (echo "copying $f failed" > /dev/stderr; exit 1)
done

if [[ -n "$(source proxy_setup.sh >/dev/null; echo $PROXY)" ]]; then
  PROXY=$(source proxy_setup.sh >/dev/null; echo $PROXY)
  echo "setting up .wgetrc's to $PROXY"
  $SSHCMD "echo \"http_proxy = http://$PROXY\" > .wgetrc"
fi

# remove deb-src lines (we do not mirror them and should not need them)
$SSHCMD "sed -i 's/^deb-src/\#deb-src/g' /etc/apt/sources.list" sudo

echo "setup chef"
$SSHCMD  "/home/ubuntu/install-chef.sh $binary_server_host $binary_server_url $chef_server_ip `hostname`" sudo

echo "zap disks"
$SSHCMD "/home/ubuntu/zap-ceph-disks.sh" sudo

echo "temporarily adjust system time to avoid time skew related failures"
GOODDATE=`date`
$SSHCMD "date -s '$GOODDATE'" sudo

echo "done."

