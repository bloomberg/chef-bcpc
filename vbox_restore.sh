#!/bin/bash

# bash imports
source ./virtualbox_env.sh

for i in `seq 1 3`; do
  $VBM controlvm bcpc-vm$i poweroff
  $VBM snapshot bcpc-vm$i restore initial-install
  vagrant ssh -c "cd chef-bcpc && knife client delete -y bcpc-vm$i.local.lan" || true
  vagrant ssh -c "cd chef-bcpc && knife node delete -y bcpc-vm$i.local.lan" || true
  $VBM startvm bcpc-vm$i
done
