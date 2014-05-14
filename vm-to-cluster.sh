#!/bin/bash
#
# Script to help making a cluster definition file (cluster.txt) from
# the current VMs known by VirtualBox. This is intended to be run on
# the hypervisor as it relies on using the VBoxManage tool
#
# cluster.txt can be used by the cluster-*.sh tools for various
# cluster automation tasks, see cluster-readme.txt
#
#set -x

# bash imports
source ./virtualbox_env.sh

if [[ -z "$1" ]]; then
	echo "Usage: $0 domain"
	exit
fi

DOMAIN=$1

function getvminfo {
	# extract the first mac address for this VM
	MAC1=`$VBM showvminfo $1 | grep "NIC 1" | grep MAC | awk '{print $4}' | awk '{print substr($0, 1, length() -1)}'`
	# add the customary colons in
	MAC1=`echo $MAC1 | sed -e 's/^\([0-9A-Fa-f]\{2\}\)/\1_/'  \
		-e 's/_\([0-9A-Fa-f]\{2\}\)/:\1_/' \
		-e 's/_\([0-9A-Fa-f]\{2\}\)/:\1_/' \
		-e 's/_\([0-9A-Fa-f]\{2\}\)/:\1_/' \
		-e 's/_\([0-9A-Fa-f]\{2\}\)/:\1_/' \
		-e 's/_\([0-9A-Fa-f]\{2\}\)/:\1/'`
	# now get the IP address
	PROPERTY=`$VBM guestproperty get $1 "/VirtualBox/GuestInfo/Net/0/V4/IP"`
	if [[ "$PROPERTY" = "No value set!" ]]; then
	    echo "$VM not booted yet" >&2
	    IP="IP unavailable - has this VM been booted?"
	else
	    IP=`echo $PROPERTY | awk '{print $2}'`
	fi
	# there's no IP address for the ILO for VMs, instead use
	# VirtualBox's graphical console
	ILOIPADDR="-"
	echo "$1 $MAC1 $IP $ILOIPADDR $DOMAIN unknown"
}

if [[ -f cluster.txt ]]; then
	echo "Found cluster.txt. Saved as cluster.txt.save$$"
	mv cluster.txt cluster.txt.save$$
	touch cluster.txt
fi

VMLIST=`$VBM list vms`
for V in $VMLIST; do
	if [[ ! "$V" =~ "{" ]]; then
		VM=`echo "$V" | awk '{print substr($0, 2, length() -2)}'`
		getvminfo $VM >> cluster.txt
	fi
done
echo "end" >> cluster.txt
echo "cluster.txt created. Please assign roles"
