#!/bin/bash

# bash imports
source ./virtualbox_env.sh

for i in `seq 1 3`; do
  $VBM snapshot bcpc-vm$i take initial-install
done
