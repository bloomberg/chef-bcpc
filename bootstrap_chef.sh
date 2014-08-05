#!/bin/bash

# Parameters:
# $1 is the vagrant install mode or user name to SSH as (see "Usage:" below)
# $2 is the IP address of the bootstrap node
# $3 is the optional knife recipe name, default "Test-Laptop"

source ./virtualbox_env.sh
source ./vmware/vmware_env.sh

if [[ $OSTYPE == msys || $OSTYPE == cygwin ]]; then
  # try to fix permission mismatch between windows and real unix
  RSYNCEXTRA="--perms --chmod=a=rwx,Da+x"
fi

set -e

DIR=`dirname $0`

if [[ $# -gt 1 ]]; then
  KEYFILE="bootstrap_chef.id_rsa"
  IP="$2"
  BCPC_DIR="chef-bcpc"
  VAGRANT=""
  VMWARE=""
  VBOX=""
  # override the ssh-user and keyfile if using Vagrant
  if [[ $1 == "--vagrant-local" ]]; then
    echo "Running on the local Vagrant VM"
    VAGRANT="true"
    VBOX="true"
    BCPC_DIR="~vagrant/chef-bcpc"
    SSH_USER="$USER"
    SSH_CMD="bash -c"
  elif [[ $1 == "--vagrant-remote" ]]; then
    echo "SSHing to the Vagrant VM"
    VAGRANT="true"
    VBOX="true"
    BCPC_DIR="~vagrant/chef-bcpc"
    SSH_USER="vagrant"
    SSH_CMD="vagrant ssh -c"
  elif [[ $1 == "--vagrant-vmware" ]]; then
    echo "SSHing to the Vagrant VM (on VMware)"
    VAGRANT="true"
    VMWARE="true"
    BCPC_DIR="~vagrant/chef-bcpc"
    SSH_USER="vagrant"
    SSH_CMD="vagrant ssh -c"
    DIR=$DIR/vmware
    if [[ -z "$VMRUN" ]]; then
      echo "vmrun not found!" >&2
      echo "  Please ensure VMWare is installed and vmrun is accessible." >&2
      exit 1
    fi
  else
    SSH_USER="$1"
    SSH_CMD="ssh -t -i $KEYFILE ${SSH_USER}@${IP}" 
    echo "SSHing to the non-Vagrant machine ${IP} as ${SSH_USER}"
  fi
  if [[ $# -ge 3 ]]; then
      CHEF_ENVIRONMENT="$3"
  else
      CHEF_ENVIRONMENT="Test-Laptop"
  fi
  echo "Chef environment: ${CHEF_ENVIRONMENT}"
else
  echo "Usage: `basename $0` --vagrant-local|--vagrant-remote|--vagrant-vmware|<user name> IP-Address [chef environment]" >> /dev/stderr
  exit
fi

# protect against rsyncing to the wrong bootstrap node
if [[ ! -f "environments/${CHEF_ENVIRONMENT}.json" ]]; then
    echo "Error: environment file ${CHEF_ENVIRONMENT}.json not found"
    exit
fi

pushd $DIR

if [[ -z $VAGRANT ]]; then
  if [[ ! -f $KEYFILE ]]; then
    ssh-keygen -N "" -f $KEYFILE
  fi
  echo "Running rsync of non-Vagrant install"
  rsync  $RSYNCEXTRA -avP -e "ssh -i $KEYFILE" --exclude vbox --exclude vmware --exclude $KEYFILE --exclude .chef . ${SSH_USER}@$IP:chef-bcpc 
  rsync  $RSYNCEXTRA -avP -e "ssh -i $KEYFILE" vbox/ubuntu-12.04-mini.iso ${SSH_USER}@$IP:chef-bcpc/cookbooks/bcpc/files/default/bins
  $SSH_CMD "cd $BCPC_DIR && ./setup_ssh_keys.sh ${KEYFILE}.pub"
else
  echo "Running rsync of Vagrant install"
  $SSH_CMD "rsync $RSYNCEXTRA -avP --exclude vbox --exclude vmware --exclude .chef /chef-bcpc-host/ /home/vagrant/chef-bcpc/"
  echo "Rsync over the hypervisor mini ISO to avoid redownloading"
  $SSH_CMD "rsync $RSYNCEXTRA -avP /chef-bcpc-host/vbox/ubuntu-12.04-mini.iso  /home/vagrant/chef-bcpc/cookbooks/bcpc/files/default/bins"
fi

echo "Updating server"
$SSH_CMD "cd $BCPC_DIR && sudo apt-get -y update && sudo apt-get -y dist-upgrade"
if [[ -n "$VBOX" && -z `$VBM snapshot bcpc-bootstrap list | grep dist-upgrade` ]]; then
  echo "Taking snapshot (VirtualBox)"
  $VBM snapshot bcpc-bootstrap take dist-upgrade-complete
fi
if [ -n "$VMWARE" ]; then
  VM_PATH=`ls -d .vagrant/machines/bootstrap/vmware_fusion/*/`
  VMX_FILE=$VM_PATH/precise64.vmx
  if [[ -z `"$VMRUN" listSnapshots $VMX_FILE | grep dist-upgrade` ]]; then
    echo "Taking snapshot (VMware)"
    "$VMRUN" snapshot $VMX_FILE dist-upgrade-complete
  fi
fi
echo "Building binaries"
$SSH_CMD "cd $BCPC_DIR && sudo ./cookbooks/bcpc/files/default/build_bins.sh"
echo "Setting up chef server"
$SSH_CMD "cd $BCPC_DIR && sudo ./setup_chef_server.sh ${IP}"
echo "Setting up chef cookbooks"
$SSH_CMD "cd $BCPC_DIR && ./setup_chef_cookbooks.sh ${IP} ${SSH_USER}"
echo "Setting up chef environment, roles, and uploading cookbooks"
$SSH_CMD "cd $BCPC_DIR && knife environment from file environments/${CHEF_ENVIRONMENT}.json && knife role from file roles/*.json && knife cookbook upload -a -o cookbooks"
echo "Enrolling local bootstrap node into chef"
$SSH_CMD "cd $BCPC_DIR && ./setup_chef_bootstrap_node.sh ${IP} ${CHEF_ENVIRONMENT}"

popd
