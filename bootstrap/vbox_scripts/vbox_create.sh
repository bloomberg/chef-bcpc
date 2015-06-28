#!/bin/bash
# Exit immediately if anything goes wrong, instead of making things worse.
set -e

# from EVW packer branch
vbm_import() {
  local -r image_name="$1"
  local -r vm_name="$2"
  shift 2
  # this currently assumes that only one virtual system is imported
  "$VBM" import "$image_name" --vsys 0 --vmname "$vm_name" "$@"
}

################################################################################
# Function to remove VirtualBox DHCP servers
# By default, checks for any DHCP server on networks without VM's & removes them
# (expecting if a remove fails the function should bail)
# If a network is provided, removes that network's DHCP server
# (or passes the vboxmanage error and return code up to the caller)
# 
function remove_DHCPservers {
  local network_name=${1-}
  if [[ -z "$network_name" ]]; then
    # make a list of VM UUID's
    local vms=$($VBM list vms|sed 's/^.*{\([0-9a-f-]*\)}/\1/')
    # make a list of networks (e.g. "vboxnet0 vboxnet1")
    local vm_networks=$(for vm in $vms; do \
      $VBM showvminfo --details --machinereadable $vm | \
      grep -i '^hostonlyadapter[2-9]=' | \
      sed -e 's/^.*=//' -e 's/"//g'; \
    done | sort -u)
    # will produce a regular expression string of networks which are in use by VMs
    # (e.g. ^vboxnet0$|^vboxnet1$)
    local existing_nets_reg_ex=$(sed -e 's/^/^/' -e '/$/$/' -e 's/ /$|^/g' <<< "$vm_networks")

    $VBM list dhcpservers | grep -E "^NetworkName:\s+HostInterfaceNetworking" | awk '{print $2}' |
    while read -r network_name; do
      [[ -n $existing_nets_reg_ex ]] && ! egrep -q $existing_nets_reg_ex <<< $network_name && continue
      remove_DHCPservers $network_name
    done
  else
    $VBM dhcpserver remove --netname "$network_name" && local return=0 || local return=$?
    return $return
  fi
}

###################################################################
# Function to create the bootstrap VM
# uses Vagrant or stands-up the VM in VirtualBox for manual install
# 
function create_bootstrap_VM {
  if which vagrant >/dev/null ; then
    echo "Vagrant detected - using Vagrant to initialize bcpc-bootstrap VM"
    mkdir -p $BCPC_VM_DIR/bcpc-bootstrap
    cp $REPO_ROOT/bootstrap/vbox_scripts/Vagrantfile.vbox $BCPC_VM_DIR/bcpc-bootstrap/Vagrantfile
    cd $BCPC_VM_DIR/bcpc-bootstrap
    vagrant up --provider virtualbox
    keyfile="$(vagrant ssh-config bootstrap | awk '/Host bootstrap/,/^$/{ if ($0 ~ /^ +IdentityFile/) print $2}')"
    if [[ -f "$keyfile" ]]; then
      cp "$keyfile" insecure_private_key
    fi
  else
    echo "Vagrant not detected - using raw VirtualBox for bcpc-bootstrap"
    # Make the three BCPC networks we'll need, but clear all nets and dhcpservers first
    for i in 0 1 2 3 4 5 6 7 8 9; do
      if [[ ! -z `$VBM list hostonlyifs | grep vboxnet$i | cut -f2 -d" "` ]]; then
        $VBM hostonlyif remove vboxnet$i || true
      fi
    done    
  
    $VBM hostonlyif create
    $VBM hostonlyif create
    $VBM hostonlyif create
  
    VBN0=vboxnet0
    VBN1=vboxnet1
    VBN2=vboxnet2

    $VBM hostonlyif ipconfig "$VBN0" --ip 10.0.100.2    --netmask 255.255.255.0
    $VBM hostonlyif ipconfig "$VBN1" --ip 172.16.100.2  --netmask 255.255.255.0
    $VBM hostonlyif ipconfig "$VBN2" --ip 192.168.100.2 --netmask 255.255.255.0

    # Create bootstrap VM if it does not exist
    if ! $VBM list vms | grep "^\"${vm}\"" ; then
      if [[ -n "$ARCHIVED_BOOTSTRAP" && -f "$ARCHIVED_BOOTSTRAP" ]]; then
        vbm_import "$ARCHIVED_BOOTSTRAP" bcpc-bootstrap
      else
        $VBM createvm --name $vm --ostype Ubuntu_64 --basefolder $P --register
        $VBM modifyvm $vm --memory $BOOTSTRAP_VM_MEM
        $VBM modifyvm $vm --cpus $BOOTSTRAP_VM_CPUS
        $VBM modifyvm $vm --vram 16
        $VBM storagectl $vm --name "SATA Controller" --add sata
        $VBM storagectl $vm --name "IDE Controller" --add ide
        # Create a number of hard disks
        port=0
        for disk in a; do
          $VBM createhd --filename $P/$vm/$vm-$disk.vdi --size $BOOTSTRAP_VM_DRIVE_SIZE
          $VBM storageattach $vm --storagectl "SATA Controller" --device 0 --port $port --type hdd --medium $P/$vm/$vm-$disk.vdi
          port=$((port+1))
        done
        # Add the bootable mini ISO for installing Ubuntu ISO
        $VBM storageattach $vm --storagectl "IDE Controller" --device 0 --port 0 --type dvddrive --medium $ISO
        $VBM modifyvm $vm --boot1 disk
      fi
      # Add the network interfaces
      $VBM modifyvm $vm --nic1 nat
      $VBM modifyvm $vm --nic2 hostonly --hostonlyadapter2 "$VBN0"
      $VBM modifyvm $vm --nic3 hostonly --hostonlyadapter3 "$VBN1"
      $VBM modifyvm $vm --nic4 hostonly --hostonlyadapter4 "$VBN2"
    fi
  fi
}

###################################################################
# Function to create the BCPC cluster VMs
# 
function create_cluster_VMs {
  # Gather VirtualBox networks in use by bootstrap VM (Vagrant simply uses the first not in-use so have to see what was picked)
  oifs="$IFS"
  IFS=$'\n'
  bootstrap_interfaces=($($VBM showvminfo bcpc-bootstrap --machinereadable|egrep '^hostonlyadapter[0-9]=' |sort|sed -e 's/.*=//' -e 's/"//g'))
  IFS="$oifs"
  VBN0="${bootstrap_interfaces[0]}"
  VBN1="${bootstrap_interfaces[1]}"
  VBN2="${bootstrap_interfaces[2]}"

  # Create each VM
  for vm in bcpc-vm1 bcpc-vm2 bcpc-vm3; do
    # Only if VM doesn't exist
    if ! $VBM list vms | grep "^\"${vm}\"" ; then
      $VBM createvm --name $vm --ostype Ubuntu_64 --register --basefolder $BCPC_VM_DIR
      $VBM modifyvm $vm --memory $CLUSTER_VM_MEM
      $VBM modifyvm $vm --cpus $CLUSTER_VM_CPUS
      $VBM modifyvm $vm --vram 16
      $VBM storagectl $vm --name "SATA Controller" --add sata
      # Create a number of hard disks
      port=0
      for disk in a b c d e; do
        $VBM createhd --filename $BCPC_VM_DIR/$vm/$vm-$disk.vdi --size $CLUSTER_VM_DRIVE_SIZE
        $VBM storageattach $vm --storagectl "SATA Controller" --device 0 --port $port --type hdd --medium $BCPC_VM_DIR/$vm/$vm-$disk.vdi
        port=$((port+1))
      done
      # If head node then add 3 more drives for ephemeral lvm storage
      if [ vm == "bcpc-vm1" ]; then
        for disk in f g h; do
          $VBM createhd --filename $BCPC_VM_DIR/$vm/$vm-$disk.vdi --size $CLUSTER_VM_DRIVE_SIZE
          $VBM storageattach $vm --storagectl "SATA Controller" --device 0 --port $port --type hdd --medium $BCPC_VM_DIR/$vm/$vm-$disk.vdi
          port=$((port+1))
        done
      fi
      # Add the network interfaces
      $VBM modifyvm $vm --nic1 hostonly --hostonlyadapter1 "$VBN0" --nictype1 82543GC
      $VBM setextradata $vm VBoxInternal/Devices/pcbios/0/Config/LanBootRom $P/gpxe-1.0.1-80861004.rom
      $VBM modifyvm $vm --nic2 hostonly --hostonlyadapter2 "$VBN1"
      $VBM modifyvm $vm --nic3 hostonly --hostonlyadapter3 "$VBN2"

      # Set hardware acceleration options
      $VBM modifyvm $vm --largepages on --vtxvpid on --hwvirtex on --nestedpaging on --ioapic on
    fi
  done
}

# only execute functions if being run and not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  remove_DHCPservers
  create_bootstrap_VM
  create_cluster_VMs
fi
