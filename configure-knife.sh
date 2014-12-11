#!/bin/bash
if [[ ! -d .chef ]]; then
  knife configure --initial <<EOF
.chef/knife.rb
http://10.0.100.3:4000


/etc/chef-server/admin.pem

/etc/chef-server/chef-validator.pem
.
welcome
EOF
else
  echo "Knife configuration already exists!"
fi
