#!/bin/bash

################################################################################
# This script designed to provide a complete one-touch install of Chef-BCPC in
# an environment with a proxy and custom DNS servers; VMs booted headlessly
# simple few environment variables to tune booting for fast testing of Chef-BCPC
# Run this script in the root of the git repository
#

set -e

if [[ "$(pwd)" != "$(git rev-parse --show-toplevel)" ]]; then
  printf '#### WARNING: This should be run in the git top level directory! ####\n' > /dev/stderr
fi

ENVIRONMENT=Test-Laptop
PROXY=proxy.example.com:80
DNS_SERVERS='"8.8.8.8", "8.8.4.4"'
export BOOTSTRAP_VM_MEM=3096
export BOOTSTRAP_VM_CPUs=2
export CLUSTER_VM_MEM=5120
export CLUSTER_VM_CPUs=4

printf "#### Setup configuration files\n"
# setup vagrant
sed -i 's/vb.gui = true/vb.gui = false/' Vagrantfile

# setup proxy_setup.sh
sed -i "s/#export PROXY=.*\"/export PROXY=\"$PROXY\"/" proxy_setup.sh

# setup environment file
sed -i "s/\"dns_servers\" : \[ \"8.8.8.8\", \"8.8.4.4\" \]/\"dns_servers\" : \[ $DNS_SERVERS \]/" environments/${ENVIRONMENT}.json
sed -i "s#\(\"bootstrap\": {\)#\1\n\"proxy\" : \"http://$PROXY\",\n#" environments/${ENVIRONMENT}.json

printf "#### Setup VB's and Bootstrap\n"
source ./vbox_create.sh

download_VM_files || ( echo "############## VBOX DOWNLOAD VM FILES RETURNED $? ##############" && exit 1 )
create_bootstrap_VM || ( echo "############## VBOX CREATE BOOTSTRAP VM RETURNED $? ##############" && exit 1 )
create_cluster_VMs || ( echo "############## VBOX CREATE CLUSTER VMs RETURNED $? ##############" && exit 1 )
install_cluster || ( echo "############## bootstrap_chef.sh returned $? ##############" && exit 1 )

printf "#### Cobbler Boot\n"
printf "Snapshotting pre-Cobbler and booting (unless already running)\n"
vms_started="False"
for i in 1 2 3; do
  vboxmanage showvminfo bcpc-vm$i | grep -q '^State:.*running' || vms_started="True"
  vboxmanage showvminfo bcpc-vm$i | grep -q '^State:.*running' || VBoxManage snapshot bcpc-vm$i take Shoe-less
  vboxmanage showvminfo bcpc-vm$i | grep -q '^State:.*running' || VBoxManage startvm bcpc-vm$i --type headless
done

printf "Checking VMs are up: \n"
while ! nc -w 1 -q 0 10.0.100.11 22 || \
         !  nc -w 1 -q 0 10.0.100.12 22 || \
         !  nc -w 1 -q 0 10.0.100.13 22
do
  sleep 60
  printf "Hosts down: "
  for m in 11 12 13; do
    nc -w 1 -q 0 10.0.100.$m 22 > /dev/null || echo -n "10.0.100.$m "
  done
  printf "\n"
done

printf "Snapshotting post-Cobbler\n"
[[ "$vms_started" == "True" ]] && VBoxManage snapshot bcpc-vm1 take Post-Cobble
[[ "$vms_started" == "True" ]] && VBoxManage snapshot bcpc-vm2 take Post-Cobble
[[ "$vms_started" == "True" ]] && VBoxManage snapshot bcpc-vm3 take Post-Cobble

printf "#### Chef all the nodes\n"
vagrant ssh -c "sudo apt-get install -y sshpass"

cobbler_pass=$(vagrant ssh -c "cd chef-bcpc; knife data bag show configs $ENVIRONMENT | grep 'cobbler-root-password:'|sed 's/.* //'")

printf "#### Chef the first headnode(s)\n"
if ! vagrant ssh -c "cd chef-bcpc; ./cluster-assign-roles.sh $ENVIRONMENT bcpc-vm1"; then 
  printf "## set the first machine to admin\n"
  vagrant ssh -c 'cd chef-bcpc; echo -e "/\"admin\": false\ns/false/true\nw\nq\n" | EDITOR=ed knife client edit `knife client list | grep bcpc-vm1`'
  # re-run chef
  vagrant ssh -c "cd chef-bcpc; echo $cobbler_pass | sudo knife bootstrap -E $ENVIRONMENT -r 'role[BCPC-Headnode]' 10.0.100.11 -x ubuntu --sudo"
fi

for i in 2 3; do
  printf "## Machine bcpc-vm${i}\n"
  vagrant ssh -c "cd chef-bcpc; ./cluster-assign-roles.sh $ENVIRONMENT bcpc-vm$i"
done

printf "Snapshotting post-Cobbler\n"
VBoxManage snapshot bcpc-vm1 take Full-Shoes
VBoxManage snapshot bcpc-vm2 take Full-Shoes
VBoxManage snapshot bcpc-vm3 take Full-Shoes
