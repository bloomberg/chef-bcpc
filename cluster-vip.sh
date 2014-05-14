#!/bin/bash
if [[ -z "$1" ]]; then
    if [[ -d environments ]]; then
	ENVIRONMENTS=`ls -lt environments/*.json | wc -l`
    else
	echo "Usage: VIP not specified and can't find environment directory"
	exit
    fi
    if (($ENVIRONMENTS == 1)); then
	VIP=`grep -i vip environments/*.json | awk '{print $3}' | awk '{print substr($0, 2, length() - 3)}'`
	echo "VIP from environment = $VIP"
    else
	echo "Usage: VIP not specified and more than one environment file found"
	exit
    fi
else 
    VIP=`grep -i vip environments/"$1".json | awk '{print $3}' | awk '{print substr($0, 2, length() - 3)}'`
    echo "VIP IP address : $VIP"
fi
if [[ ! -z `which fping` ]]; then
    # fping fails faster than ping
    UP=`fping -aq "$VIP" | awk '{print $1}'`
else
    UP=`ping -c1 "$VIP" | grep ttl | awk '{print $4}'`
fi
if [[ ! -z "$UP" ]]; then
    MAC=`arp -n $VIP | grep ether | awk '{print $3}'`
    HOST=`grep "$MAC" cluster.txt`
    echo "VIP is currently : $HOST"
else
    echo "$VIP appears to be down"
fi
