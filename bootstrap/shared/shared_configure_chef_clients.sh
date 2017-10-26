#!/bin/bash
# Exit immediately if anything goes wrong, instead of making things worse.
set -e

source "$REPO_MOUNT_POINT/bootstrap/shared/shared_functions.sh"
load_configs
REQUIRED_VARS=( BOOTSTRAP_CHEF_ENV BCPC_HYPERVISOR_DOMAIN CLUSTER )
check_for_envvars "${REQUIRED_VARS[@]}"

CLUSTER_CONFIG="$REPO_MOUNT_POINT/bootstrap/config/$CLUSTER.json"

# use Chef Server embedded knife instead of the one in /usr/bin
KNIFE=/opt/opscode/embedded/bin/knife

# Bootstrap chef client
vm_ips=$(cat ${CLUSTER_CONFIG} | jq -r '.nodes | .[] | .networks[] | select(.type == "management") | .ip')
for ip in $vm_ips; do
  $KNIFE bootstrap -x vagrant -P vagrant --sudo $ip
done

# Set Chef environment, run lists and admin privileges
vms="`cat $CLUSTER_CONFIG | jq -r '.nodes | keys | .[]'`"
for vm in $vms; do
  $KNIFE node environment set $vm.$BCPC_HYPERVISOR_DOMAIN $BOOTSTRAP_CHEF_ENV
  chef_role=`cat $CLUSTER_CONFIG | jq -r ".nodes | to_entries[] | select(.key == \"$vm\") | .value.chef_role"`
  $KNIFE node run_list set $vm.$BCPC_HYPERVISOR_DOMAIN "role[BCPC-Hardware-Virtual],role[$chef_role]"
  if [ "$chef_role" == 'BCPC-Bootstrap' ] || \
     [ "$chef_role" == 'BCPC-Headnode' ] || \
     [ "$chef_role" == 'BCPC-CephMonitorNode' ] || \
     [ "$chef_role" == 'BCPC-Monitoring' ]
  then
    $KNIFE group add client $vm.$BCPC_HYPERVISOR_DOMAIN admins
  fi
done
