#!/bin/bash
# a script to find which nodes, defined in a cluster definition file
# cluster.txt are responding to ping
COUNT=0
if [[ ! -z "$1" ]]; then
    WANTED="$1"
fi
if [[ -f cluster.txt ]]; then

    # select which hosts to scan
    while read HOSTNAME MACADDR IPADDR ILOIPADDR DOMAIN ROLE; do
	if [[ "$HOSTNAME" = end ]]; then
	    continue
	fi
	if [[ -z "$WANTED" || "$WANTED" = all || "$WANTED" = "$ROLE" || "$WANTED" = "IPADDR" || "$WANTED" = "$HOSTNAME" ]]; then
	    ALLHOSTS="$ALLHOSTS $IPADDR"
	fi
    done < cluster.txt

    if [[ -z "$ALLHOSTS" ]]; then exit; fi

    # fping is fast but might not be available
    if [[ -z `which fping` ]]; then
        # use standard ping instead 
	for IP in $ALLHOSTS; do
            UP=`ping -c 1 $IP | grep ttl |cut -f4 -d" " | cut -f1 -d":"`
            if [[ ! -z "$UP" ]]; then
		COUNT=$((COUNT + 1))
		echo $UP $ROLE
            fi
	done
    else
        # we can use fping
        UP=`fping -aq $ALLHOSTS 2> /dev/null`
        for H in $UP; do
            COUNT=$((COUNT + 1))
            echo $H
        done
    fi
    echo "$COUNT hosts up"
else
    echo "Warning : no cluster definition (cluster.txt) found"
fi
