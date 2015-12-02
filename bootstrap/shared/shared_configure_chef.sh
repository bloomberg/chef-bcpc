#!/bin/bash
# Exit immediately if anything goes wrong, instead of making things worse.
set -e

. $REPO_ROOT/bootstrap/shared/shared_functions.sh

REQUIRED_VARS=( BOOTSTRAP_CHEF_DO_CONVERGE BOOTSTRAP_CHEF_ENV BCPC_HYPERVISOR_DOMAIN FILECACHE_MOUNT_POINT REPO_MOUNT_POINT REPO_ROOT )
check_for_envvars ${REQUIRED_VARS[@]}

# This script does a lot of stuff:
# - installs Chef Server on the bootstrap node
# - installs Chef client on all nodes

# It would be more efficient as something executed in one shot on each node, but
# doing it this way makes it easy to orchestrate operations between nodes. In some cases,
# commands can be &&'d together to avoid SSHing repeatedly to a node (SSH setup/teardown
# can add a fair amount of time to this script).

cd $REPO_ROOT/bootstrap/vagrant_scripts

# use Chef Server embedded knife instead of the one in /usr/bin
KNIFE=/opt/opscode/embedded/bin/knife

# install and configure Chef Server 12 and Chef 12 client on the bootstrap node
# move nginx insecure to 4000/TCP is so that Cobbler can run on the regular 80/TCP
do_on_node bootstrap "sudo dpkg -i \$(find $FILECACHE_MOUNT_POINT/ -name chef-server\*deb -not -name \*downloaded | tail -1) \
  && sudo sh -c \"echo nginx[\'non_ssl_port\'] = 4000 > /etc/opscode/chef-server.rb\" \
  && sudo chef-server-ctl reconfigure \
  && sudo chef-server-ctl user-create admin admin admin admin@localhost.com welcome --filename /etc/opscode/admin.pem \
  && sudo chef-server-ctl org-create bcpc BCPC --association admin --filename /etc/opscode/bcpc-validator.pem \
  && sudo chmod 0644 /etc/opscode/admin.pem /etc/opscode/bcpc-validator.pem \
  && sudo dpkg -i \$(find $FILECACHE_MOUNT_POINT/ -name chef_\*deb -not -name \*downloaded | tail -1)"

# configure knife on the bootstrap node and perform a knife bootstrap to create the bootstrap node in Chef
do_on_node bootstrap "mkdir -p \$HOME/.chef && echo -e \"chef_server_url 'https://bcpc-bootstrap.$BCPC_HYPERVISOR_DOMAIN/organizations/bcpc'\\\nvalidation_client_name 'bcpc-validator'\\\nvalidation_key '/etc/opscode/bcpc-validator.pem'\\\nnode_name 'admin'\\\nclient_key '/etc/opscode/admin.pem'\\\nknife['editor'] = 'vim'\\\ncookbook_path [ \\\"#{ENV['HOME']}/chef-bcpc/cookbooks\\\" ]\" > \$HOME/.chef/knife.rb \
  && $KNIFE ssl fetch \
  && $KNIFE bootstrap -x vagrant -P vagrant --sudo 10.0.100.3"

# Initialize VM lists
vms="vm1 vm2 vm3"
if [ $MONITORING_NODES -gt 0 ]; then
  i=1
  while [ $i -le $MONITORING_NODES ]; do
    mon_vm="vm`expr 3 + $i`"
    mon_vms="$mon_vms $mon_vm"
    i=`expr $i + 1`
  done
fi

# install the knife-acl plugin into embedded knife, rsync the Chef repository into the non-root user
# (vagrant)'s home directory, and add the dependency cookbooks from the file cache
do_on_node bootstrap "sudo /opt/opscode/embedded/bin/gem install $FILECACHE_MOUNT_POINT/knife-acl-0.0.12.gem \
  && rsync -a $REPO_MOUNT_POINT/* \$HOME/chef-bcpc \
  && cp $FILECACHE_MOUNT_POINT/cookbooks-r6/*.tar.gz \$HOME/chef-bcpc/cookbooks \
  && cd \$HOME/chef-bcpc/cookbooks && ls -1 *.tar.gz | xargs -I% tar xvzf %"

# build binaries before uploading the bcpc cookbook
# (this step will change later but using the existing build_bins script for now)
do_on_node bootstrap "sudo apt-get update \
  && cd \$HOME/chef-bcpc \
  && sudo bash -c 'export FILECACHE_MOUNT_POINT=$FILECACHE_MOUNT_POINT \
  && source \$HOME/proxy_config.sh && bootstrap/shared/shared_build_bins.sh'"

# upload all cookbooks and our chosen environment to the Chef server
# (cookbook upload uses the cookbook_path set when configuring knife on the bootstrap node)
do_on_node bootstrap "$KNIFE cookbook upload -a"
do_on_node bootstrap "cd \$HOME/chef-bcpc/environments && $KNIFE environment from file $BOOTSTRAP_CHEF_ENV.json"

# install and bootstrap Chef on cluster nodes
i=1
for vm in $vms $mon_vms; do
  do_on_node $vm "sudo dpkg -i \$(find $FILECACHE_MOUNT_POINT/ -name chef_\*deb -not -name \*downloaded | tail -1)"
  do_on_node bootstrap "$KNIFE bootstrap -x vagrant -P vagrant --sudo 10.0.100.1${i}"
  i=`expr $i + 1`
done

# augment the previously configured nodes with our newly uploaded environments and roles
ENVIRONMENT_SET=""
for vm in bootstrap $vms $mon_vms; do
  ENVIRONMENT_SET="$ENVIRONMENT_SET $KNIFE node environment set bcpc-$vm.$BCPC_HYPERVISOR_DOMAIN $BOOTSTRAP_CHEF_ENV && "
done
ENVIRONMENT_SET="$ENVIRONMENT_SET :"
do_on_node bootstrap $ENVIRONMENT_SET

do_on_node bootstrap "$KNIFE node run_list set bcpc-bootstrap.$BCPC_HYPERVISOR_DOMAIN 'recipe[role-bcpc-bootstrap]' \
  && $KNIFE node run_list set bcpc-vm1.$BCPC_HYPERVISOR_DOMAIN 'recipe[role-bcpc-node-head]' \
  && $KNIFE node run_list set bcpc-vm2.$BCPC_HYPERVISOR_DOMAIN 'recipe[role-bcpc-node-work-osd]' \
  && $KNIFE node run_list set bcpc-vm3.$BCPC_HYPERVISOR_DOMAIN 'recipe[role-bcpc-node-work-ephemeral]'"

# generate actor map and set bootstrap, vm1 and mon vms (if any) as admins so that they can write into the data bag
ADMIN_SET="cd \$HOME && $KNIFE actor map && "
for vm in bootstrap vm1 $mon_vms; do
  ADMIN_SET="$ADMIN_SET $KNIFE group add actor admins bcpc-$vm.$BCPC_HYPERVISOR_DOMAIN && "
done
ADMIN_SET="$ADMIN_SET :"
do_on_node bootstrap $ADMIN_SET

# Clustered monitoring setup (>1 mon VM) requires completely initialized node attributes for chef to run
# on each node successfully. If we are not converging automatically, set run_list (for mon VMs) and exit.
# Otherwise, each mon VM needs to complete chef run first before setting the next node's run_list.
if [[ $BOOTSTRAP_CHEF_DO_CONVERGE -eq 0 ]]; then
  for vm in $mon_vms; do
    do_on_node bootstrap "$KNIFE node run_list set bcpc-$vm.$BCPC_HYPERVISOR_DOMAIN 'role[BCPC-Monitoring]'"
  done
  echo "BOOTSTRAP_CHEF_DO_CONVERGE is set to 0, skipping automatic convergence."
  exit 0
else
  # run Chef on each node
  do_on_node bootstrap "sudo chef-client"
  for vm in $vms; do
    do_on_node $vm "sudo chef-client"
  done
  # run on head node one last time to update HAProxy with work node IPs
  do_on_node vm1 "sudo chef-client"
  # HUP OpenStack services on each node to ensure everything's in a working state
  for vm in $vms; do
    do_on_node $vm "sudo hup_openstack || true"
  done
  # Run chef on each mon VM before assigning next node for monitoring.
  for vm in $mon_vms; do
    do_on_node bootstrap "$KNIFE node run_list set bcpc-$vm.$BCPC_HYPERVISOR_DOMAIN 'role[BCPC-Monitoring]'"
    do_on_node $vm "sudo chef-client"
  done
  # Run chef on each mon VM except the last node to update cluster components
  for vm in $(echo $mon_vms | awk '{$NF=""}1'); do
    do_on_node $vm "sudo chef-client"
  done
fi
