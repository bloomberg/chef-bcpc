#!/bin/bash
# A script to enroll cluster nodes in cobbler based on a cluster
# definition in cluster.txt :
#
# - If a node is provided, that node will be addded or removed depending
#   on the first parameter
#
# - if no node is provided, the first parameter will be used to choose
#   an action to apply to all nodes
#
# - if a special nodename is provided that matches a role, then all
#   hosts with that role will have the specified cobbler action (add
#   or remove) applied to them. [Technically cobbler doesn't know
#   anything about roles, however it can be convenient to register,
#   say, all head nodes first, get them up and running without any
#   risk of work nodes accidentally coming up before they have a head
#   node to talk to, and then register all work nodes later.]
#
# If any cobbler registrations were changed, cobbler sync is called
#
if [[ -z "$1" ]]; then
  echo "Usage: $0 add|remove (hostname)"
  exit
fi

if [[ ! -z "$2" ]]; then
    EXACTHOST=$2
fi

TRANSCRIPT="cobbler-transcript.txt"
if [[ -f $TRANSCRIPT ]]; then
    touch $TRANSCRIPT
fi

if [[ -f cluster.txt ]]; then
    echo "Using cluster definition from cluster.txt"
    while read HOSTNAME MACADDR IPADDR ILOIPADDR DOMAIN ROLE; do
	if [[ $HOSTNAME = "end" ]]; then
	    continue
	fi

	if [[ "$ROLE" = "bootstrap" ]]; then
	    # let's not try to cobbler boot ourselves
	    continue
	fi
	
	if [[ $1 = add ]];then
		if [[ -z "$EXACTHOST" || "$EXACTHOST" = "$HOSTNAME" || "$EXACTHOST" = "$ROLE" ]]; then
		MATCH="$HOSTNAME"
		ACTIONSTRING="adding $HOSTNAME.$DOMAIN ($IPADDR,$MACADDR) to cobbler..."
		echo $ACTIONSTRING | tee -a $TRANSCRIPT
		sudo cobbler system add --name=$HOSTNAME --hostname=$HOSTNAME.$DOMAIN --profile=bcpc_host --ip-address=$IPADDR --mac=$MACADDR
	    fi
	elif [[ $1 == remove ]]; then
		if [[ -z "$EXACTHOST" || "$EXACTHOST" = "$HOSTNAME" || "$EXACTHOST" = "$ROLE" ]]; then
		MATCH="$HOSTNAME"
		ACTIONSTRING="removing $HOSTNAME from cobbler..."
		echo $ACTIONSTRING | tee -a $TRANSCRIPT
		sudo cobbler system remove --name=$HOSTNAME
	    fi
	else
	    echo "Usage: \"$1\" unrecognized"
	    exit
	fi
    done < cluster.txt
else
    echo "Error: No cluster definition (cluster.txt) available"
    exit
fi

if [[ ! -z "$MATCH" ]]; then
    # made at least one change to cobbler config
    echo "Cobbler sync..."
    sudo cobbler sync
else
    if [[ -z "$EXACTHOST" ]]; then
	echo No hosts defined, no action taken.
    else
	echo Error : Host "'$2'" unrecognized, no action taken.
    fi
fi

