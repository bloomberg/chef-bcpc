#/bin/sh
#
# A utility to take some of the manual labor out of the non-Vagrant
# based chef-bcpc bringup procedure on VMs
# 

echo "this is not working yet"
exit

# bash imports
source ./virtualbox_env.sh

UP=`$VBM showvminfo bcpc-bootstrap | grep -i State`
if [[ ! $UP =~ running ]]; then
    # This just doesn't seem to work
#    $VBM modifyvm bcpc-bootstrap --nic1 bridged --bridgeadapter1 en0
    $VBM startvm bcpc-bootstrap
    sleep 30
else
    echo "bcpc-bootstrap is running"
fi
./vm-to-cluster.sh bloomberg.com
while read HOSTNAME MACADDR IPADDR ILOIPADDR DOMAIN ROLE; do
    if [[ $HOSTNAME = "end" ]]; then
        break;
    fi
    if [[ "$HOSTNAME" = bcpc-bootstrap ]]; then
        NATADDR=$IPADDR
        echo "bcpc-bootstrap is currently at (NAT) address $NATADDR"
        break
    fi
done < cluster.txt
if [[ -z $NATADDR ]]; then
    echo "Couldn't find the bootstrap node's IP address"
    exit 1
else 
    for ATTEMPT in A B C D E F G; do
        if [[ "$1" ]]; then
            HOST="$1"
        else
            HOST="$NATADDR"
        fi
	if hash fping 2>/dev/null; then
            UP=`fping -aq ${HOST} | awk '{print $1}'`
	else
	    UP=`ping -c 1 ${HOST} | grep ttl |cut -f4 -d" " | cut -f1 -d":"`
	fi
        if [[ -z "$UP" ]]; then
            echo "VM is not up yet or is unreachable"
            if [[ $ATTEMPT = G ]]; then
                echo "Maybe machine needs rework. Rerun this when it's up"
                exit 1
            fi
            sleep 5
        else
            break
        fi
    done
    SSHCOMMON="-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o VerifyHostKeyDNS=no"
    SSHCMD="ssh $SSHCOMMON"
    SCPCMD="scp $SSHCOMMON"
    if hash sshpass 2>/dev/null; then
	EDITED=`sshpass -p ubuntu $SSHCMD -t ubuntu@$HOST "echo ubuntu | sudo -S grep 'Static interfaces' /etc/network/interfaces"`
	echo "EDITED = $EDITED"
    else
	echo "please install sshpass"
	exit 1
    fi
    if [[ "$EDITED" =~ "Static interfaces" ]]; then
        echo "interfaces file appears adjusted already"
        exit 0
    else
        echo "copy interfaces file fragment..."
        sshpass -p ubuntu $SCPCMD -p "vm-eth.txt" "ubuntu@$HOST:/tmp"
        echo "add the network definitions"
        # can't simply cat file >> file when updating the interfaces, due to the permissions
        # rename does work to atomically replace the file
        sshpass -p ubuntu $SSHCMD -t ubuntu@$HOST "echo ubuntu | sudo -S cp -p /etc/network/interfaces /etc/network/interfaces.orig"
        sshpass -p ubuntu $SSHCMD -t ubuntu@$HOST "echo ubuntu | sudo -S cat /etc/network/interfaces /tmp/vm-eth.txt > /tmp/combined.txt"
        sshpass -p ubuntu $SSHCMD -t ubuntu@$HOST "echo ubuntu | sudo -S mv /tmp/combined.txt /etc/network/interfaces"
        echo "restart networking"
        sshpass -p ubuntu $SSHCMD -t ubuntu@$HOST "echo ubuntu | sudo -S service networking restart"
    fi
fi
