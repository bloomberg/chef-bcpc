#!/bin/bash
# Script to assign roles to cluster nodes based on a definition in cluster.txt:
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
# - if a chef object is provided, e.g. role[ROLE-NAME] or
#   recipe[RECIPE-NAME], only nodes marked for that action are attempted
#
# - A node may be excluded by setting its action to SKIP

set -x
set -o errtrace
set -o errexit
set -o nounset

# We use eclamation point as a separator but it is a pain to use in strings with variables
# make it a variable to include in strings
BANG='!'
# Global Regular Expression for parsing parse_cluster_txt output
REGEX='(.*)!(.*)!(.*)'
# Knife administrative credentials
KNIFE_ADMIN="-u admin -k /etc/chef-server/admin.pem"

########################################################################
# install_machines -  Install a set of machines (will run chefit.sh if no node object for machine)
# Argument: $1 - a string of role!IP!FQDN pairs separated by white space
# Will install the machine with role $role in the order passed (left to right)
function install_machines {
  passwd=`sudo knife data bag show configs $ENVIRONMENT $KNIFE_ADMIN | grep "cobbler-root-password:" | awk ' {print $2}'`
  for h in $(sort <<< ${*// /\\n}); do
    [[ "$h" =~ $REGEX ]]
    local run_list="${BASH_REMATCH[1]}"
    local ip="${BASH_REMATCH[2]}"
    local fqdn="${BASH_REMATCH[3]}"
    if sudo knife node show $fqdn $KNIFE_ADMIN 2>/dev/null >/dev/null; then
      printf "Running chef for node $fqdn in $ENVIRONMENT run_list ${run_list}...\n"
      local SSHCMD="./nodessh.sh $ENVIRONMENT $ip"
      sudo knife node run_list set $fqdn "$run_list" $KNIFE_ADMIN
      $SSHCMD "chef-client -o '$run_list'" sudo
    else
      printf "About to bootstrap node $fqdn in $ENVIRONMENT run_list ${run_list}...\n"
      ./chefit.sh $ip $ENVIRONMENT
      sudo -E knife bootstrap -E $ENVIRONMENT -r "$run_list" $ip -x ubuntu ${passwd:+-P} $passwd $KNIFE_ADMIN --sudo <<< $passwd
    fi
  done
}

#############################################################################################
# parse cluster.txt 
# Argument: $1 - optional case insensitive match text (e.g. hostname, ipaddress, chef object)
# Returns: List of matching hosts (or all non-skipped hosts) one host per line with ! delimited fileds
# (Note: if you want to skip a machine, set its role to SKIP in cluster.txt)
function parse_cluster_txt {
  local match_text=${1-}
  local hosts=""
  while read host macaddr ipaddr iloipaddr domain role; do
    shopt -s nocasematch
    if [[ -z "${match_text-}" || "$match_text" = "$host" || "$match_text" = "$ipaddr" || "$role" =~ $match_text ]] && \
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
# Runs: Chef role[Basic], Chef recipe[bcpc::default], recipe[bcpc::networking]
# Argument: $* - hosts are returned by parse_cluster_txt
function install_stub {
  printf "Creating stubs for nodes...\n"
  for h in $*; do
    [[ "$h" =~ $REGEX ]]
    local role="${BASH_REMATCH[1]}"
    local ip="${BASH_REMATCH[2]}"
    local fqdn="${BASH_REMATCH[3]}"
    sudo knife node show $fqdn $KNIFE_ADMIN 2>/dev/null >/dev/null ||  install_machines "role[Basic],recipe[bcpc::default],recipe[bcpc::networking]${BANG}${ip}${BANG}${fqdn}" &
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
# (this ensures all headnodes know of eachother)
# Lastly, install workers in parallel)
function openstack_install {
  local hosts="$*"
  shopt -u nocasematch
  printf "Doing OpenStack style install...\n"

  first_head_node=$(printf ${hosts// /\\n} | grep -i "head" | sort | head -1)
  [[ "$first_head_node" =~ $REGEX ]] && first_head_node_fqdn="${BASH_REMATCH[3]}" || \
    (printf "Failed to parse hosts\n"; exit 1 )
  # chef does not always use the same hostname as cluster.txt (be fast and loose and find the chef hostname)
  first_head_node_hostname=${first_head_node_fqdn%%.*}
  install_stub "$first_head_node"
  # set the first node to admin for creating data bags (short-circuit failures in-case machine already is an admin)
  chef_head_node_name=$(sudo knife client list $KNIFE_ADMIN | egrep "^${first_head_node_hostname}\..*$|^${first_head_node_hostname}$")
  printf "/\"admin\": false\ns/false/true\nw\nq\n" | EDITOR=ed sudo -E knife client edit $chef_head_node_name $KNIFE_ADMIN || /bin/true

  # Do head nodes first and group by type of head
  printf "Installing heads...\n"
  install_machines $(printf ${hosts// /\\n} | grep -i "head" | sort)
  # Redo head nodes in reverse order to ensure they know about eachother
  # (the last node already knows everyone in the universe of heads)
  printf "Acquainting heads...\n"
  install_machines $(printf ${hosts// /\\n} | grep -i "head" | sort | head -n -1 | tac)
  # Do everything else next and group by type of node
  printf "Installing workers...\n"
  for m in $(printf ${hosts// /\\n} | grep -vi "head" | sort); do
    ( install_machines $m || exit 1 )&
  done
  wait
  # remove admin from first headnode
  printf "/\"admin\": true\ns/true/false\nw\nq\n" | EDITOR=ed sudo -E knife client edit "$chef_head_node_name" $KNIFE_ADMIN 
}

########################################################################
# Perform Hadoop install
# Arguments: $* - hosts (as output from parse_cluster_txt)
# Method:
# * Installs stubs (create chef nodes and setup networking) for all machines in parallel
# * Set all headnode to admins
# * Assigns roles for headnodes
# * Installs headnodes sorted by role
# * Unsets all headnode from being admins
# * Installs worknodes in parallel
function hadoop_install {
  local hosts="$*"
  shopt -u nocasematch
  printf "Doing Hadoop style install...\n"
  # to prevent needing to re-chef headnodes the Hadoop code base assumes
  # all nodes and clients have been created and further that all roles
  # have been assigned before any node Chefing begins
  install_stub $(printf ${hosts// /\\n} | sort)

  printf "Assigning roles for headnodes...\n"
  for h in $(printf ${hosts// /\\n} | grep -i "head" | sort); do
    [[ "$h" =~ $REGEX ]]
    local role="${BASH_REMATCH[1]}"
    local ip="${BASH_REMATCH[2]}"
    local fqdn="${BASH_REMATCH[3]}"
    sudo knife node run_list add $fqdn "$role" $KNIFE_ADMIN &
  done

  # set the headnodes to admin for creating data bags
  for h in $(printf ${hosts// /\\n} | grep -i "head" | sort); do
    [[ "$h" =~ $REGEX ]]
    printf "/\"admin\": false\ns/false/true\nw\nq\n" | EDITOR=ed sudo -E knife client edit "${BASH_REMATCH[3]}" $KNIFE_ADMIN || /bin/true
  done

  printf "Installing heads...\n"
  install_machines $(printf ${hosts// /\\n} | grep -i "head" | sort)

  # remove admin from the headnodes
  for h in $(printf ${hosts// /\\n} | grep -i "head" | sort); do
    [[ "$h" =~ $REGEX ]]
    printf "/\"admin\": true\ns/true/false\nw\nq\n" | EDITOR=ed sudo -E knife client edit "${BASH_REMATCH[3]}" $KNIFE_ADMIN 
  done

  printf "Installing workers...\n"
  for m in $(printf ${hosts// /\\n} | grep -vi "head" | sort); do
    install_machines $m &
  done
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
if [[ ! "$INSTALL_TYPE" =~ (openstack|hadoop) ]]; then
  printf "Error: Need install type of OpenStack or Hadoop\n" > /dev/stderr
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

shopt -s nocasematch
if [[ "$INSTALL_TYPE" = "OpenStack" ]]; then
  openstack_install $hosts
### Hadoop Install Method
elif [[ "$INSTALL_TYPE" = "Hadoop" ]]; then
  hadoop_install $hosts
fi

printf "#### Install finished\n"
