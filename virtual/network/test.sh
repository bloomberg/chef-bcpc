#!/bin/bash
#
# Quick ping tester script. For a list of VMs A .. C ping each from
# each other
#
while [[ -n "$1" ]]; do
    if [[ "$1" = "-v" ]]; then
        VERBOSE=true
    else
        echo "Usage: $0 [-v] "
        echo "Unrecognized \"$1\""
        exit
    fi
    shift
done

# conditional printf
function vftrace {
    if [[ -n "$VERBOSE" ]]; then
        printf "$@"
    fi
}

# the hard-coded IPs. We can glean this from a declarative leaf/spine
# configuration file once we have that. For now hard-code
IP1="192.168.0.2"
IP2="192.168.0.66"
IP3="192.168.0.130"

declare -a ADDRS
ADDRS[1]=$IP1
ADDRS[2]=$IP2
ADDRS[3]=$IP3

# set up SSH to never complain abot host keys and to reuse persistent
# connections. Maybe overkill for a few pings, but will be useful if
# we start doing more
SSHCMD="vagrant ssh"
SOCKETDIR=${HOME}/.ssh/sockets
if [[ ! -d $SOCKETDIR ]]; then
    mkdir ${SOCKETDIR}
    chmod a+rwx ${SOCKETDIR}
else
    ls ${SOCKETDIR}
fi

SSHOPTS=""
SSHOPTS+="-o ControlMaster=auto "
SSHOPTS+="-o ControlPath=${SOCKETDIR}/%r@%h-%p "
SSHOPTS+="-o ControlPersist=600 "
SSHOPTS+="-q -o UserKnownHostsFile=/dev/null "
SSHOPTS+="-o StrictHostKeyChecking=no "
SSHOPTS+="-o VerifyHostKeyDNS=no"


# For each HV, loop through all HVs again and ping the ones that
# aren't the source
NUMHVS=3
vftrace "HV IPs : $IP1 $IP2 $IP3\n\n"
for IP in `seq -s" " 1 ${NUMHVS}`; do
    for OTHER in `seq -s" " 1 ${NUMHVS}`; do
        if [[ "$IP" -ne "$OTHER" ]]; then
            CMD="$CMD ping -c1 ${ADDRS[OTHER]} ;"
            printf "hv${IP} -> hv${OTHER} : "
            if [[ -n "$VERBOSE" ]]; then
                ${SSHCMD} hv${IP} -c "${CMD}"   -- ${SSHOPTS}
            else
                ${SSHCMD} hv${IP} -c "${CMD}"   -- ${SSHOPTS} > /dev/null 2>&1
            fi

            if [[ $? -eq 0 ]]; then
                printf "pass\n"
            else
                printf "fail\n"
            fi
            CMD=""
        fi
    done
done
