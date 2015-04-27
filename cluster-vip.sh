#!/bin/bash
if [[ -z "$1" ]]; then
    if [[ -d environments ]]; then
        ENVIRONMENTS=`ls -lt environments/*.json | wc -l`
    else
        echo "Usage: VIP not specified and can't find environment directory"
        exit
    fi
    if (($ENVIRONMENTS == 1)); then
        VIPFILE=environments/*.json
    else
        echo "Usage: VIP not specified and more than one environment file found"
        exit
    fi
else
    VIPFILE=environments/"$1".json
fi

grep -i vip $VIPFILE|tr -d ':' > /tmp/vips.txt
while read V IPADDRESS; do
    VIP=`echo $IPADDRESS | tr -d \" | tr -d ,`
    if [[ ! -z `which fping` ]]; then
        # fping fails faster than ping
        UP=`fping -aq "$VIP" | awk '{print $1}'`
    else
        UP=`ping -c1 "$VIP" | grep ttl | awk '{print $4}'`
    fi
    if [[ ! -z "$UP" ]]; then
        MAC=""
        HOST=""
        # try to lookup via arp, it's fast
        MAC=`arp -n $VIP | grep ether | awk '{print $3}'`
        if [[ -z $MAC ]]; then
            echo "arp lookup of $VIP failed"
        else
            HOST=`grep -i "$MAC" cluster.txt`
        fi
        if [[ -n $HOST ]]; then
            echo "$VIP is currently on : $HOST"
        else
            # current location may not be on same layer 2 network as
            # VIP, so search by connecting to each known hosts
            echo "Searching for $VIP host by host"
            while read HOST MAC IP IP2 DOMAIN ROLE OVERRIDE; do
                MATCH=`./nodessh.sh $1 $IP "ip a | grep ${VIP}"`
                if [[ -n $MATCH && $MATCH =~ inet ]]; then
                    HOST=`grep -i "$HOST" cluster.txt`
                    echo "$VIP is currently on : $HOST"
                    break
                fi
            done < cluster.txt
        fi
    else
        echo "$VIP appears to be down"
    fi
done < /tmp/vips.txt
rm /tmp/vips.txt
