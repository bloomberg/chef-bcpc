#!/bin/bash

# adjust the following to suit your cluster
STORAGE_NETWORK_PREFIX="10.0.100"

set -x
sudo sed -i -e '/public network/ s/^/#/'  /etc/ceph/ceph.conf
sudo sed -i -e '/cluster network/ s/^/#/' /etc/ceph/ceph.conf
HOST=$(hostname)
ADDR=`ifconfig -a | grep -i $STORAGE_NETWORK_PREFIX | awk '{print $2}' | cut -f2 -d':'`
sudo ceph-mon --cluster=ceph --id=$HOST --public-addr=$ADDR -f
set +x
