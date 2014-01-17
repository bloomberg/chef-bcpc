#!/bin/bash

# Parameters : 
# $1 is the IP address of the bootstrap node
# $2 is the Chef environment name, default "Test-Laptop"

set -e
set -x

if [[ $# -ne 2 ]]; then
	echo "Usage: `basename $0` IP-Address Chef-Environment" >> /dev/stderr
	exit
fi

CHEF_SERVER=$1
CHEF_ENVIRONMENT=$2

# Assume we are running in the chef-bcpc directory

# Are we running under Vagrant?  If so, jump through some extra hoops.
sudo chef-client -E "$CHEF_ENVIRONMENT" -c .chef/knife.rb
sudo chown $(whoami):root .chef/$(hostname -f).pem
sudo chmod 550 .chef/$(hostname -f).pem

admin_val=`knife client show $(hostname -f) -c .chef/knife.rb | grep ^admin: | sed "s/admin:[^a-z]*//"`
if [[ "$admin_val" != "true" ]]; then
  # Make this client an admin user before proceeding.
  echo -e "/\"admin\": false\ns/false/true\nw\nq\n" | EDITOR=ed sudo -E knife client edit `hostname -f` -c .chef/knife.rb -k /etc/chef-server/admin.pem -u admin
fi

knife node run_list add $(hostname -f) 'role[BCPC-Bootstrap]' -c .chef/knife.rb
sudo chef-client -c .chef/knife.rb
