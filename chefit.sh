#!/bin/bash
#
# 
#
#set -x
IP="$1"
ENVIRONMENT="$2"
echo "initial configuration of $IP"

# we should have no ill effect running proxy_setup but do need the proxy variables
source proxy_setup.sh

SCPCMD="./nodescp    $ENVIRONMENT $IP"
SSHCMD="./nodessh.sh $ENVIRONMENT $IP"

echo "copy files..."
$SCPCMD zap-ceph-disks.sh ubuntu@$IP:/home/ubuntu
$SCPCMD install-chef.sh   ubuntu@$IP:/home/ubuntu
$SCPCMD finish-worker.sh  ubuntu@$IP:/home/ubuntu
$SCPCMD finish-head.sh    ubuntu@$IP:/home/ubuntu

if [[ -n "$http_proxy" ]]; then
  echo "setting up .wgetrc's to $http_proxy with no_proxy $no_proxy"
  $SSHCMD "echo -e \"http_proxy = $http_proxy\\nhttps_proxy = $https_proxy\\nno_proxy = $no_proxy\" > .wgetrc"
  load_chef_server_ip $ENVIRONMENT
  temp_file="apt_proxy.tmp"
  # copy /etc/apt/apt.conf.d/90proxy to append to or create if non-existant
  $SSHCMD "cp /etc/apt/apt.conf.d/90proxy $temp_file || touch $temp_file"
  # add necessary proxy lines in /etc/apt/apt.conf.d/90proxy if not there already
  apt_no_proxy="Acquire::http::Proxy::$chef_server_ip \\\"DIRECT\\\""
  $SSHCMD "grep -q '${apt_no_proxy}' /etc/apt/apt.conf.d/90proxy" || $SSHCMD "cat >> $temp_file <<<\"${apt_no_proxy};\""
  $SSHCMD "mv $temp_file /etc/apt/apt.conf.d/90proxy" sudo
fi

echo "setup chef"
$SSHCMD  "/home/ubuntu/install-chef.sh" sudo

echo "zap disks"
$SSHCMD "/home/ubuntu/zap-ceph-disks.sh" sudo

echo "temporarily adjust system time to avoid time skew related failures"
GOODDATE=`date`
$SSHCMD "date -s '$GOODDATE'" sudo

echo "done."

