#!/bin/bash
# Script to assign roles to cluster nodes based on a definition in cluster.txt :
#
# - The environment is needed to find the root password of the machines
#   and to provide the environment in which to chef them
#
# - An install_type is needed; options are OpenStack or Hadoop
#
# - If no hostname is provided, all nodes will be attempted
#
# - if a nodename is provided, either by hostname or ip address, only
#   that node will be attempted
#
# - if the special nodename "heads" is given, all head nodes will be
#   attempted
#
# - if the special nodename "workers" is given, all work nodes will be
#   attempted
#
# - A node may be excluded by setting its role to something other than
#   "head" or "work" in cluster.txt. For example "done" might be
#   useful for nodes that have been completed

set -e
set -x

if [[ -z "$2" ]]; then
  printf "Usage : $0 environment install_type (hostname)\n" > /dev/stderr
  exit 1
fi

ENVIRONMENT=$1
INSTALL_TYPE=$2
EXACTHOST=$3

shopt -s nocasematch
if [[ ! "$INSTALL_TYPE" =~ (openstack|hadoop) ]]; then 
  printf "Error: Need install type of OpenStack or Hadoop\n" > /dev/stderr
  exit 1
fi
shopt -u nocasematch

if [[ ! -f "environments/$ENVIRONMENT.json" ]]; then   
  printf "Error: Couldn't find '$ENVIRONMENT.json'. Did you forget to pass the environment as first param?\n" > /dev/stderr
  exit 1
fi

########################################################################
# install_machines -  Install a set of machines
# Argument: $1 - a string of role!IP!FQDN pairs separated by white space
# Will install the machine with role $role
function install_machines {
  PASSWD=`knife data bag show configs $ENVIRONMENT | grep "cobbler-root-password:" | awk ' {print $2}'`
  for h in $(sort <<< ${*// /\\n}); do
    local regEx='(.*)!(.*)!.*'
    [[ "$h" =~ $regEx ]]
    local role="${BASH_REMATCH[1]}"
    local ip="${BASH_REMATCH[2]}"
    printf "About to bootstrap node ${role}...\n"
    ./chefit.sh $ip $ENVIRONMENT
    local SSHCMD="./nodessh.sh $ENVIRONMENT $ip"
    sudo knife bootstrap -E $ENVIRONMENT -r "role[$role]" $ip -x ubuntu  -P $PASSWD -u admin -k /etc/chef-server/admin.pem --sudo <<< $PASSWD
  done
}

# if you want to skip a machine, set its role to SKIP  
while read HOST MACADDR IPADDR ILOIPADDR DOMAIN ROLE; do
  shopt -s nocasematch
  if [[ -z "$EXACTHOST" || "$EXACTHOST" = "$HOST" || "$EXACTHOST" = "$IPADDR" || "$EXACTHOST" = "$ROLE" ]] && [[ ! "|$ROLE" =~ '|SKIP' ]]; then
    hosts="$host ${ROLE}!${IPADDR}!${HOST}.$DOMAIN"
  fi
  shopt -u nocasematch
done < cluster.txt


for h in $hosts; do
  regEx='(.*)!(.*)!(.*)'
  [[ "$h" =~ $regEx ]]
  role="${BASH_REMATCH[1]}"
  ip="${BASH_REMATCH[2]}"
  fqdn="${BASH_REMATCH[3]}"
  printf "%s\t-\t%s\n" $role $fqdn
done | sort

if [[ -z "$hosts" ]]; then
  printf "Warning: No nodes found\n" > /dev/stderr
  exit 0
fi

shopt -s nocasematch
if [[ "$INSTALL_TYPE" = "OpenStack" ]]; then
  shopt -u nocasematch
  printf "Doing OpenStack style install...\n"
  # Do head nodes first and group by type of head
  printf "Installing heads...\n"
  install_machines $(printf ${hosts// /\\n} | grep -i "head" | sort)
  # Redo head nodes in reverse order to ensure they know about eachother
  # (the last node already knows everyone in the universe of heads)
  printf "Acquainting heads...\n"
  install_machines $(printf ${hosts// /\\n} | grep -i "head" | sort | head -n -1 | tac)
  # Do everything else next and group by type of node  
  printf "Installing workers...\n"
  install_machines $(printf ${hosts// /\\n} | grep -vi "head" | sort)
elif [[ "$INSTALL_TYPE" = "Hadoop" ]]; then
  shopt -u nocasematch
  regEx='(.*)!(.*)!(.*)'
  printf "Doing Hadoop style install...\n"
  # to prevent needing to re-chef headnodes the Hadoop code base assumes
  # all nodes and clients have been created and further that all roles
  # have been assigned before any headnode Chefing begins
  printf "Creating stubs for headnodes...\n"
  for h in $(printf ${hosts// /\\n} | grep -i "head" | sort); do
    [[ "$h" =~ $regEx ]]
    role="${BASH_REMATCH[1]}"
    ip="${BASH_REMATCH[2]}"
    install_machines "Basic!$ip!NONE"
  done

  printf "Assigning roles for headnodes...\n"
  for h in $(printf ${hosts// /\\n} | grep -i "head" | sort); do
    [[ "$h" =~ $regEx ]]
    role="${BASH_REMATCH[1]}"
    ip="${BASH_REMATCH[2]}"
    fqdn="${BASH_REMATCH[3]}"
    knife node run_list add $fqdn "role[$role]"
  done

  # set the first node to admin for creating data bags 
  [[ "$(printf ${hosts// /\\n} | grep -i "head" | sort | head -1)" =~ $regEx ]]
  printf "/\"admin\": false\ns/false/true\nw\nq\n" | EDITOR=ed knife client edit "${BASH_REMATCH[3]}" || /bin/true

  printf "Installing heads...\n"
  install_machines $(printf ${hosts// /\\n} | grep -i "head" | sort)

  # unset the first node being an admin to lessen security footprint
  [[ "$(printf ${hosts// /\\n} | grep -i "head" | sort | head -1)" =~ $regEx ]]
  printf "/\"admin\": true\ns/true/false\nw\nq\n" | EDITOR=ed knife client edit "${BASH_REMATCH[3]}"

  printf "Installing workers...\n"
  install_machines $(printf ${hosts// /\\n} | grep -vi "head" | sort)
fi

