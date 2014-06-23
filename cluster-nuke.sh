#!/bin/bash
#
# A tool to wipe the by-products of a cluster bringup from a bootstrap
# node but leave the bootstrap node and related roles, nodes, clients
# etc undamaged
#
# Usage cluster_nuke.sh <environment>
#
if [[ -z "$1" ]]; then
    echo "Usage : $0 'environment'"
    echo "did nothing..."
    exit
fi
ENVIRONMENT="$1"
if [[ ! -f "cluster.txt" ]]; then
    echo "I am a bear of very little brain so I couldn't find the cluster.txt file. No clusters were harmed in the making of this error message"
    exit
fi
if [[ ! -f "environments/${ENVIRONMENT}.json" ]]; then
    echo "You are scaring me now, I don't see the environment file you asked for. Not doing nothing"
    exit
fi
while read HOSTNAME MACADDR IPADDR ILOIPADDR DOMAIN ROLE; do
    if [[ "$ROLE" = "bootstrap" ]]; then
	BOOTSTRAP_NODE="$HOSTNAME"
	BOOTSTRAP_DOMAIN="$DOMAIN"
	echo "Ignoring $HOSTNAME - bootstrap node to be retained"
    elif [[ "$ROLE" = "work" || "$ROLE" = "head" ]]; then
	#
	# Build a list of entries to remove from the databag.
        #
        # Extend the above test if there are other roles that cluster
	# members can have
	CLUSTER_MEMBERS="${CLUSTER_MEMBERS} ${HOSTNAME}"
    else
	echo "Ignoring $HOSTNAME - unknown role"
    fi
done < cluster.txt
if [[ -z "$BOOTSTRAP_NODE" ]]; then
    echo "No bootstrap node found, unsafe to continue. Are you nuts?"
    exit
fi

# cross check that what I think is the bootstrap node for this domain
# based on the cluster definition file cluster appears correctly as a
# node in the databag
BOOT_FQDN="${BOOTSTRAP_NODE}.${BOOTSTRAP_DOMAIN}"
echo "BOOT FQDN = ${BOOT_FQDN}"
MATCH=`knife node list | grep $BOOT_FQDN`
if [[ ! -z "$MATCH" ]]; then
    echo "Plausible level of consistency present : it looks to me like I should delete all nodes and clients except $MATCH..."
else
    echo "$BOOT_FQDN not found in data bag, unsafe to continue. Can't fool me that way!"
    exit
fi
echo "Making safety copy of ${ENVIRONMENT} configs..."
DATABAG_BACKUP="~/$ENVIRONMENT.databag.$$"
knife data bag show configs "${ENVIRONMENT}" >> "${DATABAG_BACKUP}"
echo "Databag configs for ${ENVIRONMENT} dumped to ${DATABAG_BACKUP}"

echo "Deleting data bag configs..."
knife data bag delete configs

echo "Removing clients and nodes..."
for CLIENT in $CLUSTER_MEMBERS; do
    knife client delete "${CLIENT}.${BOOTSTRAP_DOMAIN}"
    knife node   delete "${CLIENT}.${BOOTSTRAP_DOMAIN}"
done

echo "reload knife data..."
knife role from file roles/*.json
knife role from file roles/*.rb
knife cookbook upload -a -o cookbooks
knife environment from file "environments/${ENVIRONMENT}.json"

echo "Removing cobbler systems..."
for CLIENT in "${CLUSTER_MEMBERS}"; do
    SOMETHING="${CLIENT}"
    sudo cobbler system remove --name=${CLIENT}
done

if [[ ! -z "$SOMETHING" ]]; then
    echo "Sync cobbler..."
    sudo cobbler sync
fi

echo "Removing cobbler profile..."
sudo cobbler profile remove --name=bcpc_host
sudo cobbler sync

# Prevent stale kickstart being installed
echo "Hiding stale kickstart in case Chef goes all wibbly..."
KICKSTART_FILE="/var/lib/cobbler/kickstarts/bcpc_ubuntu_host.preseed"
sudo mv "${KICKSTART_FILE}" "${KICKSTART_FILE}.old.$$"

echo "Rerunning Chef client ..."
sudo chef-client
sudo chef-client
sudo chef-client

echo "Checking results ..."
CHECK=`knife data bag show configs ${ENVIRONMENT} | grep -i cobbler-root`
if [[ -z "$CHECK" ]]; then
    echo "Warning, no cobbler-root found. I'm so sorry."
    exit
else
    echo "Cobbler-root found : ${CHECK}"
fi

echo "Verifying kickstarts..."
CHECK=`sudo cobbler profile dumpvars --name=bcpc_host | grep kickstart | grep bcpc`
if [[ -z "$CHECK" ]]; then
    echo "Warning, no BCPC kickstart data found. Duh!"
    exit
else
    echo "Found BCPC kickstart : ${CHECK}"
fi

echo "Succesfully took off and nuked the site from orbit. It's the only way to be sure."
