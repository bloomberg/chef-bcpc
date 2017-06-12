#!/bin/bash

vm_prefix='ansible'

# Dynamic candidate list, no static declarations
candidate_list=( ${vm_prefix}-bcpc-bootstrap ${vm_prefix}-bcpc-vm{1..3} )

# Clean up and reap the VMs by _EXACT_ name, not prefixes
for vm in "${candidate_list[@]}"; do 
	VBoxManage showvminfo "$vm" >/dev/null 2>&1 || continue;
	VBoxManage controlvm "$vm" poweroff && true
	VBoxManage unregistervm "$vm" --delete
done
