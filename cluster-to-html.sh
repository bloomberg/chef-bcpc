#!/bin/bash
#
# Helper to make a web page with links to hosts and their consoles
# (ILOs). Pass the name of the cluster as an optional parameter to
# customise the page title.
#
# At present this is mainly to make it easier to navigate to the ILO
# console of a machine based on its hostname instead of cutting and
# pasting. The host link is not currently useful. This will be
# expanded to emit more useful host links at some point.
#
# This script expects a file cluster.txt to exist and have the format:
# HOSTNAME MACADDRESS IPADDR ILOIPADDR DOMAIN ROLE
#
# Usage : ./cluster-to-html.sh MYCLUSTER > mycluster.html
#
#
if [[ ! -z "$1" ]]; then
	CLUSTERNAME="$1"
fi
if [[ ! -f "cluster.txt" ]]; then
	"Error: cluster.txt not found"
	exit
fi
echo -e "<html>"
echo -e "<head>\n<title>Cluster $CLUSTERNAME members</title></head>"
echo -e "<body>"
echo -e "<font color=slategray>\n<h2>Cluster $CLUSTERNAME members</h2>\n</font>"
echo -e "<table border=\"1\">"
while read HOSTNAME MACADDR IPADDR ILOIPADDR DOMAIN ROLE; do
	if [[ "$ROLE" = "head" ]]; then
		COLOR=red
	elif [[ "$ROLE" = "bootstrap" ]]; then
		COLOR=purple
	else
		COLOR=black
	fi
	echo -e "<tr>"
	echo -e "<td>$HOSTNAME</td>"
	echo -e "<td><a href=\"https://$IPADDR\">host</a></td>"
	echo -e "<td><a href=\"https://$ILOIPADDR\">ilo</a></td>"
	echo -e "<td>"
	echo -e "<font color=$COLOR>"
	echo -e "$ROLE"
	echo -e "</font>"
	echo -e "</td>"
	echo -e "</tr>"
done < cluster.txt
echo -e "</table>"
echo -e "</body>"
echo -e "</html>"