#!/bin/bash
#
# A simple tool to check the basics of our cluster - machines up, services running
# This tool uses the cluster hardware list file cluster.txt
#
# The first param specifies the environment
#
# For the second, optional param :
# - if no param is passed, or 'all', all nodes are checked
# - if 'head' is passed only head nodes are checked
# - if 'work' is passed only work nodes are checked
# - if an IP address or hostname is passed, just that node is checked
# 
# If any third param is passed, output is verbose, otherwise only
# output considered an exception is passed. You have to provide a 2nd
# param to allow a 3rd param to be recognized as simple positional
# param processing is used
#
# This may be helpful as a quick check after completing the knife
# bootstrap phase (assigning roles to nodes).
#
if [[ -z "$1" ]]; then
    echo "Usage $0 'environment' [role|IP] [verbose]"
    exit
fi
if [[ -z `which fping` ]]; then
    echo "This tool uses fping. You should be able to install fpring with `sudo apt-get install fping`"
    exit
fi

echo "$0 : Checking which hosts are online..."
UPHOSTS=`./cluster-whatsup.sh $2`

#set -x
ENVIRONMENT="$1"
HOSTWANTED="$2"
VERBOSE="$3"
# verbose trace - information that's not normally needed
function vtrace {
    if [[ ! -z "$VERBOSE" ]]; then
        for STR in "$@"; do
            echo -e $STR
        done
    fi
}

declare -A HOSTNAMES

if [[ -f cluster.txt ]]; then
    while read HOSTNAME MACADDR IPADDR ILOIPADDR DOMAIN ROLE; do
        if [[ $HOSTNAME = "end" ]]; then
            continue
        fi
	if [[ "$ROLE" = "bootstrap" ]]; then
	    continue
	fi
	THISUP="false"
	for UPHOST in $UPHOSTS; do
	    if [[ "$IPADDR" = "$UPHOST" ]]; then
		THISUP="true"
		UP=$[UP + 1]
	    fi
	done
        if [[ -z "$HOSTWANTED" || "$HOSTWANTED" = all || "$HOSTWANTED" = "$ROLE" || "$HOSTWANTED" = "$IPADDR" || "$HOSTWANTED" = "$HOSTNAME" ]]; then
#       HOSTS="$HOSTS $HOSTNAME"
	    if [[ "$THISUP" = "false" ]]; then
		echo "$HOSTNAME is down"
		continue
	    else
		vtrace "$HOSTNAME is up"
	    fi
            HOSTS="$HOSTS $IPADDR"
	    IDX=`echo $IPADDR | tr '.' '-'`
	    HOSTNAMES["$IDX"]="$HOSTNAME"
        fi
    done < cluster.txt
    vtrace "HOSTS = $HOSTS"
    echo
    
    for HOST in $HOSTS; do

	echo "Checking name resolution"
	./nodessh.sh $ENVIRONMENT $HOST "grep -m1 server /etc/ntp.conf | cut -f2 -d' ' > /tmp/clusterjunk.txt "
	./nodessh.sh $ENVIRONMENT $HOST "cat /tmp/clusterjunk.txt | xargs -n1 host"

	echo "checking NTP server"
	./nodessh.sh $ENVIRONMENT $HOST "cat /tmp/clusterjunk.txt | xargs -n1 ping -c 1"

	IDX=`echo $HOST | tr '.' '-'`
	NAME=${HOSTNAMES["$IDX"]}
	vtrace "Checking $NAME ($HOST)..."

	ROOTSIZE=`./nodessh.sh $ENVIRONMENT $HOST "df -k / | grep -v Filesystem"`
	ROOTSIZE=`echo $ROOTSIZE | awk '{print $4}'`
	ROOTGIGS=$((ROOTSIZE/(1024*1024)))
	if [[ $ROOTSIZE -eq 0 ]]; then
	    echo "Root fileystem size = $ROOTSIZE ($ROOTGIGS GB) !!WARNING!!"
	    echo "Machine may still be installing the operating system ... skipping"
	    continue
	elif [[ $ROOTSIZE -lt 100*1024*1024 ]]; then
	    echo "Root fileystem size = $ROOTSIZE ($ROOTGIGS GB) !!WARNING!!"
	else
            vtrace "Root fileystem size = $ROOTSIZE ($ROOTGIGS GB) "
	fi

# ugh, so slow
#	printf "Disks : "
#	for DISK in sda sdb sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm; do
#	    DISKTHERE=`./nodessh.sh $ENVIRONMENT $HOST "/sbin/fdisk -l /dev/$DISK"`
#	    # this is a bit tricksy. Invoking fdisk without root
#	    # privilege on a disk that is present raises an error, but
#	    # does nothing if the device is not there at all - so a
#	    # "present/notpresent" check is implemented as
#	    # non-null-string/null-string
#	    if [[ ! -z "$DISKTHERE" ]]; then
#	        printf "$DISK "
#	    else
#		printf "!$DISK "
#	    fi
#	done
#	printf "\n"

        if [[ -z `./nodessh.sh $ENVIRONMENT $HOST "ip route show table mgmt | grep default"` ]]; then
            echo "$HOST no mgmt default route !!WARNING!!"
	    BADHOSTS="$BADHOSTS $HOST"
        else
            vtrace "$HOST has a default mgmt route"
            MG=$[MG + 1]
        fi
        if [[ -z `./nodessh.sh $ENVIRONMENT $HOST "ip route show table storage | grep default"` ]]; then
            echo "$HOST has no storage default route !!WARNING!!"
	    BADHOSTS="$BADHOSTS $HOST"
        else
            vtrace "$HOST has a default storage route"
            SG=$[SG + 1]
        fi
        CHEF=`./nodessh.sh $ENVIRONMENT $HOST "which chef-client"`
        if [[ -z "$CHEF" ]]; then
            echo "$HOST doesn't seem to have chef installed so probably hasn't been assigned a role"
            echo
            continue
        fi
        STAT=`./nodessh.sh $ENVIRONMENT $HOST "ceph -s | grep HEALTH" sudo`
        STAT=`echo $STAT | cut -f2 -d:`
        if [[ "$STAT" =~ "HEALTH_OK" ]]; then
            vtrace "$HOST ceph : healthy"
        else
            printf "$HOST %20s %s\n" ceph "$STAT"
        fi
        # fluentd has a ridiculous status output from the normal
        # service reporting (something like "* ruby running"), try to
        # do better, according to this:
        # http://docs.treasure-data.com/articles/td-agent-monitoring
        # Roughly speaking if we have two lines of output from the
        # following ps command it's in good shape, if not dump the
        # entire output of that command to the status. This needs more
        # work
        FLUENTD=`./nodessh.sh $ENVIRONMENT $HOST "ps w -C ruby -C td-agent --no-heading | grep -v chef-client" sudo`
        STAT=`./nodessh.sh $ENVIRONMENT $HOST "ps w -C ruby -C td-agent --no-heading | grep -v chef-client | wc -l" sudo`
        STAT=`echo $STAT | cut -f2 -d:`  
        if [[ "$STAT" =~ 2 ]]; then
            if [[ ! -z "$VERBOSE" ]]; then 
		printf "$HOST %20s %s\n" "fluentd" "normal"
	    fi
        else
            printf "$HOST %20s %s\n" fluentd "$FLUENTD"
        fi
        for SERVICE in keystone glance-api glance-registry cinder-scheduler cinder-volume cinder-api nova-api nova-novncproxy nova-scheduler nova-consoleauth nova-cert nova-conductor nova-compute nova-network haproxy; do
            STAT=`./nodessh.sh $ENVIRONMENT $HOST "service $SERVICE status | grep running" sudo`
            if [[ ! "$STAT" =~ "unrecognized" ]]; then
                STAT=`echo $STAT | cut -f2 -d":"`
                if [[ ! "$STAT" =~ "start/running" ]]; then
                    printf "$HOST %20s %s\n" "$SERVICE" "$STAT"
		    BADHOSTS="$BADHOSTS $HOST"
                else
            # couldn't get a "verbose printf" function to work
                    if [[ ! -z "$VERBOSE" ]]; then
                        printf "$HOST %20s %s\n" "$SERVICE" "$STAT"
                    fi
                fi
            fi
        done
        echo
    done
else
    echo "Warning 'cluster.txt' not found"
fi
echo "$ENVIRONMENT cluster summary: $UP hosts up. $MG hosts with default mgmt route. $SG hosts with default storage route"
BADHOSTS=`echo $BADHOSTS | uniq | sort`
if [[ ! -z "$BADHOSTS" ]]; then
    echo "Bad hosts $BADHOSTS - definite issues on these"
fi