#!/bin/bash

# Parameters:
# $1 is the vagrant install mode or user name to SSH as (see "Usage:" below)
# $2 is the IP address of the bootstrap node
# $3 is the optional knife recipe name, default "Test-Laptop"

if [[ $OSTYPE == msys || $OSTYPE == cygwin ]]; then
  # try to fix permission mismatch between windows and real unix
  RSYNCEXTRA="--perms --chmod=a=rwx,Da+x"
fi

set -e

if [[ $# -gt 1 ]]; then
  KEYFILE="bootstrap_chef.id_rsa"
  IP="$2"
  BCPC_DIR="chef-bcpc"
  VAGRANT=""
  # override the ssh-user and keyfile if using Vagrant
  if [[ $1 == "--vagrant-local" ]]; then
    echo "Running on the local Vagrant VM"
    VAGRANT="true"
    BCPC_DIR="~vagrant/chef-bcpc"
    SSH_USER="$USER"
    SSH_CMD="bash -c"
  elif [[ $1 == "--vagrant-remote" ]]; then
    echo "SSHing to the Vagrant VM"
    VAGRANT="true"
    BCPC_DIR="~vagrant/chef-bcpc"
    SSH_USER="vagrant"
    SSH_CMD="vagrant ssh -c"
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
  echo "Usage: `basename $0` --vagrant-local|--vagrant-remote|<user name> IP-Address [chef environment]" >> /dev/stderr
  exit
fi

DIR=`dirname $0`
pushd $DIR

# protect against rsyncing to the wrong bootstrap node
if [[ ! -f "environments/${CHEF_ENVIRONMENT}.json" ]]; then
    echo "Error: environment file ${CHEF_ENVIRONMENT}.json not found"
    exit
fi


if [[ -z $VAGRANT ]]; then
  if [[ ! -f $KEYFILE ]]; then
    ssh-keygen -N "" -f $KEYFILE
  fi
  echo "Running rsync of non-Vagrant install"
  rsync  $RSYNCEXTRA -avP -e "ssh -i $KEYFILE" --exclude vbox --exclude $KEYFILE --exclude .chef . ${SSH_USER}@$IP:chef-bcpc 
  $SSH_CMD "cd $BCPC_DIR && ./setup_ssh_keys.sh ${KEYFILE}.pub"
else
  echo "Running rsync of Vagrant install"
  $SSH_CMD "rsync $RSYNCEXTRA -avP --exclude vbox --exclude .chef /chef-bcpc-host/ /home/vagrant/chef-bcpc/"
fi


echo "Building bins"
$SSH_CMD "cd $BCPC_DIR && sudo ./build_bins.sh"
echo "Setting up chef server"
$SSH_CMD "cd $BCPC_DIR && sudo ./setup_chef_server.sh ${CHEF_ENVIRONMENT}"
echo "Setting up chef cookbooks"
$SSH_CMD "cd $BCPC_DIR && ./setup_chef_cookbooks.sh ${IP} ${SSH_USER} ${CHEF_ENVIRONMENT}"
set -x
echo "Setting up chef environment, roles, and uploading cookbooks"
$SSH_CMD "cd $BCPC_DIR && sudo knife environment from file environments/${CHEF_ENVIRONMENT}.json -u admin -k /etc/chef-server/admin.pem"
$SSH_CMD "cd $BCPC_DIR && sudo knife role from file roles/*.json -u admin -k /etc/chef-server/admin.pem; r=\$? && sudo knife role from file roles/*.rb -u admin -k /etc/chef-server/admin.pem; r=\$((r & \$? )) && [[ \$r -lt 1 ]]"
$SSH_CMD "cd $BCPC_DIR && sudo knife cookbook upload -a -o cookbooks -u admin -k /etc/chef-server/admin.pem"

echo "Enrolling local bootstrap node into chef"
$SSH_CMD "cd $BCPC_DIR && ./setup_chef_bootstrap_node.sh ${IP} ${CHEF_ENVIRONMENT}"

popd
