#!/bin/bash -e

# Parameters : 
# $1 is the IP address of the bootstrap node
# $2 is the Chef environment name, default "Test-Laptop"

if [[ $# -ne 2 ]]; then
	echo "Usage: `basename $0` IP-Address Chef-Environment" >> /dev/stderr
	exit
fi

# Assume we are running in the chef-bcpc directory

# Are we running under Vagrant?  If so, jump through some extra hoops.
if [[ -d /home/vagrant ]]; then
  knife bootstrap -E $2 $1 -i /chef-bcpc-host/vbox/insecure_private_key -x vagrant --sudo
else
  knife bootstrap -E $2 $1 -x ubuntu --sudo
fi

admin_val=`knife client show $(hostname -f) | grep ^admin: | sed "s/admin:[^a-z]*//"`
if [[ "$admin_val" != "true" ]]; then
  # Make this client an admin user before proceeding.
  echo -e "/\"admin\": false\ns/false/true\nw\nq\n" | EDITOR=ed knife client edit `hostname -f`
fi

knife node run_list add $(hostname -f) 'role[BCPC-Bootstrap]'
sudo chef-client
