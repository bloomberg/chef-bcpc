#!/bin/bash
#
# nodessh.sh
#
# Convenience script for running commands over ssh to BCPC nodes when
# their cobbler root passwd is available in the chef databags. 
#
# Parameters:
# $1 is the name of chef environment file, without the .json file extension
# $2 is the IP address or name of the node on which to execute the specified command
# $3 is the command to execute (use "-" for an interactive shell)
# $4 (optional) if 'sudo' is specified, the command will be executed using sudo
#
if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
	NAME=$(basename "$0")
	if [[ "$NAME" = nodescp ]]; then		
		echo "Usage: $0 'environment' 'nodename|IP address' 'from' 'to'"
	else
		echo "Usage: $0 'environment' 'nodename|IP address' 'command' (sudo)"
    fi
	exit
fi

if [[ -z `which sshpass` ]]; then
    echo "Error: sshpass required for this tool. You should be able to 'sudo apt-get install sshpass' to get it"
    exit
fi

ENVIRONMENT=$1
NODE=$2
COMMAND=$3

# verify we can access the data bag for this environment
KNIFESTAT=`knife data bag show configs $ENVIRONMENT 2>&1 | grep ERROR`
if [[ ! -z "$KNIFESTAT" ]]; then
    echo "knife error $KNIFESTAT when showing the config"
    exit
fi

# get the cobbler root passwd from the data bag
PASSWD=`knife data bag show configs $ENVIRONMENT | grep "cobbler-root-password:" | awk ' {print $2}'`
if [[ -z "$PASSWD" ]]; then
    echo "Failed to retrieve 'cobbler-root-password'"
    exit
fi

IP=$2

# check if the specified host is responding
#UP=`ping -c 1 $IP | grep ttl`
#if [[ -z "$UP" ]]; then
#    echo "Node $NODEFQDN($IP) doesn't appear to be on-line"
#    exit
#fi

SSHCOMMON="-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o VerifyHostKeyDNS=no"

if [[ $(basename "$0") == nodescp ]]; then
    SCPCMD="scp $SSHCOMMON"
    sshpass -p $PASSWD $SCPCMD -p "$3" "$4"
else
    # finally ... run the specified command
    # the -t creates a pty which ensures we see errors if the command fails

    SSHCMD="ssh $SSHCOMMON"

    if [[ "$4" == sudo ]]; then
        # if we need to sudo, pipe the passwd to that too
	sshpass -p $PASSWD $SSHCMD -t ubuntu@$IP "echo $PASSWD | sudo -S $COMMAND"
    else  
        # not sudo, do it the normal way
	if [[ "$COMMAND" == - ]]; then
	    echo "You might need this : cobbler_root = $PASSWD"
	    sshpass -p $PASSWD $SSHCMD -t ubuntu@$IP
	else
	    sshpass -p $PASSWD $SSHCMD -t ubuntu@$IP "$COMMAND"
	fi
    fi
fi 

