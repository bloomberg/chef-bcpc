#!/bin/bash
if [[ -z "$2" ]]; then
    echo "Usage $0: <chef-server-url> <chef-server-password>"
    exit 1
fi
CHEFSERVER="$1"
CHEFPASSWD="$2"
if [[ ! -d .chef ]]; then
  knife configure --initial <<EOF
.chef/knife.rb
${CHEFSERVER}


/etc/chef-server/admin.pem

/etc/chef-server/chef-validator.pem
.
${CHEFPASSWD}
EOF
else
  echo "Knife configuration already exists!"
fi
