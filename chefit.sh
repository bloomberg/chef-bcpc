#!/bin/bash
#
# 
#
#set -x
IP="$1"
ENVIRONMENT="$2"
echo "initial configuration of $IP"

SCPCMD="./nodescp    $ENVIRONMENT $IP"
SSHCMD="./nodessh.sh $ENVIRONMENT $IP"

echo "Checking for Chef ..."

CHEF=`$SSHCMD "which chef-client || true"`

if [[ -z "$CHEF" ]]; then

    echo "copy files..."
    $SCPCMD zap-ceph-disks.sh /home/ubuntu
    $SCPCMD cookbooks/bcpc/files/default/bins/chef-client.deb /home/ubuntu
    $SCPCMD install-chef.sh   /home/ubuntu
    $SCPCMD finish-worker.sh  /home/ubuntu
    $SCPCMD finish-head.sh    /home/ubuntu

    if [[ -n "$(source proxy_setup.sh >/dev/null; echo $PROXY)" ]]; then
	PROXY=$(source proxy_setup.sh >/dev/null; echo $PROXY)
	echo "setting up .wgetrc's to $PROXY"
	$SSHCMD "echo \"http_proxy = http://$PROXY\" > .wgetrc"
    fi

    echo "setup chef"
    $SSHCMD  "/home/ubuntu/install-chef.sh" sudo
else
    echo "Chef is installed as $CHEF"
fi

echo "zap disks"
$SSHCMD "/home/ubuntu/zap-ceph-disks.sh" sudo

echo "temporarily adjust system time to avoid time skew related failures"
GOODDATE=`date`
$SSHCMD "date -s '$GOODDATE'" sudo

echo "done."

