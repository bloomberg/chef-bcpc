#!/bin/bash
# Script to assign roles to cluster nodes based on a definition in cluster.txt:
#
# * The environment is needed to find the root password of the machines
#   and to provide the environment in which to chef them
#
# * An install_type is needed; options are OpenStack
#
# * A node specifier may be provided:
#   If no specifier is provided, all nodes will be attempted
#
#   - if a nodename is provided, either by hostname or IP address, only
#     that node will be attempted
#
#   - if a chef object is provided, e.g. role[ROLE-NAME] or
#     recipe[RECIPE-NAME], only nodes marked for that action are attempted
#
# * A node may be excluded by setting its action to SKIP in cluster.txt

set -x
set -o errtrace
set -o errexit
set -o nounset

# If one finds timing issues for installing worknodes, set this to 1
# and all worknodes will sequentially install, instead of installing
# in parallel
REQUIRE_SEQUENTIAL_WORKER_INSTALL=${REQUIRE_SEQUENTIAL_WORKER_INSTALL-0}

# We use exclamation point as a separator but it is a pain to use in
# strings with variables make it a variable to include in strings
BANG='!'
# Global Regular Expression for parsing parse_cluster_txt output
REGEX='(.*)!(.*)!(.*)'

########################################################################
# install_machines -  Install a set of machines (will run chefit.sh if no node object for machine)
# Argument: $1 - a string of role!IP!FQDN pairs separated by white space
# Will install the machine with role $role in the order passed (left to right)
function install_machines {
  passwd=`knife data bag show configs $ENVIRONMENT | grep "cobbler-root-password:" | awk ' {print $2}'`
  for h in $(sort <<< ${*// /\\n}); do
    [[ "$h" =~ $REGEX ]]
    local run_list="${BASH_REMATCH[1]}"
    local ip="${BASH_REMATCH[2]}"
    local fqdn="${BASH_REMATCH[3]}"
    printf "About to bootstrap node $fqdn to $ENVIRONMENT ${run_list}...\n"
    knife node show $fqdn 2>/dev/null >/dev/null || ./chefit.sh $ip $ENVIRONMENT
    local SSHCMD="./nodessh.sh $ENVIRONMENT $ip"
    sudo knife bootstrap -E $ENVIRONMENT -r "$run_list" $ip -x ubuntu  -P $passwd -u admin -k /etc/chef-server/admin.pem --sudo <<< $passwd
  done
}

#############################################################################################
# parse cluster.txt 
# Argument: $1 - optional case insensitive match text (e.g. hostname, ipaddress, chef object)
# Returns: List of matching hosts (or all non-skipped hosts) one host per line with ! delimited fields
# (Note: if you want to skip a machine, set its role to SKIP in cluster.txt)
function parse_cluster_txt {
  local match_text=${1-}
  local hosts=""
  while read host macaddr ipaddr iloipaddr domain role; do
    shopt -s nocasematch
    if [[ -z "${match_text-}" || "$match_text" = "$host" || "$match_text" = "$ipaddr" || "$match_text" = "$role" ]] && \
       [[ ! "|$role" =~ '|SKIP' ]]; then
      hosts="$hosts ${role}${BANG}${ipaddr}${BANG}${host}.$domain"
    fi
    shopt -u nocasematch
  done < cluster.txt
  printf "$hosts"
}

##########################################
# Install Machine Stub
# Function to create basic machine representation (in parallel) if Chef does not
# already know about machine
# Runs: Chef role[Basic], Chef recipe[bcpc::default]
# Argument: $* - hosts are returned by parse_cluster_txt
function install_stub {
  printf "Creating stubs for nodes...\n"
  for h in $*; do
    [[ "$h" =~ $REGEX ]]
    local role="${BASH_REMATCH[1]}"
    local ip="${BASH_REMATCH[2]}"
    local fqdn="${BASH_REMATCH[3]}"
    knife node show $fqdn 2>/dev/null >/dev/null ||  install_machines "role[Basic],recipe[bcpc::default]${BANG}${ip}${BANG}${fqdn}" &
  done
  wait
}

########################################################################
# Perform OpenStack install
# Arguments: $* - hosts (as output from parse_cluster_txt)
# Runs the end-to-end install in the proper order for OpenStack installs
# Install method:
# First, install first headnode -- which needs to be an admin
# Next, install head-nodes start to finish and back to start synchronously
# (this ensures all headnodes know of each other)
# Lastly, install workers in parallel)
function openstack_install {
  local hosts="$*"
  printf "Doing OpenStack style install...\n"

  first_head_node=$(printf ${hosts// /\\n} | grep -i "head" | sort | head -1)
  if [[ "$first_head_node" =~ $REGEX ]]; then
    first_head_node_fqdn="${BASH_REMATCH[3]}" || \
      (printf "Failed to parse hosts\n"; exit 1 )
    # chef does not always use the same hostname as cluster.txt (be fast and loose and find the chef hostname)
    first_head_node_hostname=${first_head_node_fqdn%%.*}
    install_stub "$first_head_node"
    # set the first node to admin for creating data bags (short-circuit failures in-case machine already is an admin)
    chef_head_node_name=$(knife client list | egrep "^[ ]*${first_head_node_hostname}\..*$|^${first_head_node_hostname}$")
    printf "/\"admin\": false\ns/false/true\nw\nq\n" | EDITOR=ed knife client edit $chef_head_node_name || /bin/true
  fi

  # Do head nodes first and group by type of head
  printf "Installing heads...\n"
  install_machines $(printf ${hosts// /\\n} | grep -i "head" | sort)
  # Redo head nodes in reverse order to ensure they know about each other
  # (the last node already knows everyone in the universe of heads)
  printf "Acquainting heads...\n"
  install_machines $(printf ${hosts// /\\n} | grep -i "head" | sort | head -n -1 | tac)
  # Do everything else next and group by type of node
  printf "Installing workers...\n"
  for m in $(printf ${hosts// /\\n} | grep -vi "head" | sort); do
    if (( REQUIRE_SEQUENTIAL_WORKER_INSTALL == 1 )); then
      printf "Sequential install of work node ${m}\n"
      install_machines $m
    else
      ( install_machines $m || exit 1 )&
    fi
  done
  wait
  if [[ -n "${chef_head_node_name-}" ]]; then
    # remove admin from first headnode
    printf "/\"admin\": true\ns/true/false\nw\nq\n" | EDITOR=ed knife client edit $chef_head_node_name
  fi
}

############
# Main Below
#

if [[ "${#*}" -lt "2" ]]; then
  printf "Usage : $0 environment install_type (hostname)\n" > /dev/stderr
  exit 1
fi

ENVIRONMENT=$1
INSTALL_TYPE=$2
MATCHKEY=${3-}

shopt -s nocasematch
if [[ ! "$INSTALL_TYPE" =~ openstack ]]; then
  printf "Error: Need install type of OpenStack\n" > /dev/stderr
  exit 1
fi
shopt -u nocasematch

if [[ ! -f "environments/$ENVIRONMENT.json" ]]; then
  printf "Error: Couldn't find '$ENVIRONMENT.json'. Did you forget to pass the environment as first param?\n" > /dev/stderr
  exit 1
fi

# Report which hosts were found
hosts="$(parse_cluster_txt $MATCHKEY)"
for h in $hosts; do
  [[ "$h" =~ $REGEX ]]
  role="${BASH_REMATCH[1]}"
  ip="${BASH_REMATCH[2]}"
  fqdn="${BASH_REMATCH[3]}"
  printf "%s\t-\t%s\n" $role $fqdn
done | sort 

if [[ -z "${hosts-}" ]]; then
  printf "Warning: No nodes found\n" > /dev/stderr
  exit 0
fi

openstack_install $hosts

printf "#### Install finished\n"
