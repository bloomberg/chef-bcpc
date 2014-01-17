#!/bin/bash -e

if [[ "$OSTYPE" == msys || "$OSTYPE" == cygwin ]]; then
  WIN=TRUE
fi

set -x

if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi
if [[ -z "$CURL" ]]; then
  echo "CURL is not defined"
  exit
fi

VBM=VBoxManage
if ! hash $VBM ; then
  echo "You do not appear to have $VBM from VirtualBox"
  exit 1
fi

# Bootstrap VM Defaults (these need to be exported for Vagrant's Vagrantfile)
export BOOTSTRAP_VM_MEM=2048
export BOOTSTRAP_VM_CPUs=1
# Use this if you intend to make an apt-mirror in this VM (see the
# instructions on using an apt-mirror towards the end of bootstrap.md)
# -- Vagrant VMs do not use this size --
#BOOTSTRAP_VM_DRIVE_SIZE=120480

# Cluster VM Defaults
CLUSTER_VM_MEM=2048
CLUSTER_VM_CPUs=1
CLUSTER_VM_DRIVE_SIZE=20480

VBOX_DIR=`dirname $0`/vbox
P=`python -c "import os.path; print os.path.abspath(\"${VBOX_DIR}/\")"`

######################################################
# Function to download files necessary for VM stand-up
# 
function download_VM_files {
  pushd $P

  if [[ ! -f gpxe-1.0.1-80861004.rom ]]; then
    $CURL -o gpxe-1.0.1-80861004.rom "http://rom-o-matic.net/gpxe/gpxe-1.0.1/contrib/rom-o-matic/build.php" -H "Origin: http://rom-o-matic.net" -H "Host: rom-o-matic.net" -H "Content-Type: application/x-www-form-urlencoded" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Referer: http://rom-o-matic.net/gpxe/gpxe-1.0.1/contrib/rom-o-matic/build.php" -H "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3" --data "version=1.0.1&use_flags=1&ofmt=ROM+binary+%28flashable%29+image+%28.rom%29&nic=all-drivers&pci_vendor_code=8086&pci_device_code=1004&PRODUCT_NAME=&PRODUCT_SHORT_NAME=gPXE&CONSOLE_PCBIOS=on&BANNER_TIMEOUT=20&NET_PROTO_IPV4=on&COMCONSOLE=0x3F8&COMSPEED=115200&COMDATA=8&COMPARITY=0&COMSTOP=1&DOWNLOAD_PROTO_TFTP=on&DNS_RESOLVER=on&NMB_RESOLVER=off&IMAGE_ELF=on&IMAGE_NBI=on&IMAGE_MULTIBOOT=on&IMAGE_PXE=on&IMAGE_SCRIPT=on&IMAGE_BZIMAGE=on&IMAGE_COMBOOT=on&AUTOBOOT_CMD=on&NVO_CMD=on&CONFIG_CMD=on&IFMGMT_CMD=on&IWMGMT_CMD=on&ROUTE_CMD=on&IMAGE_CMD=on&DHCP_CMD=on&SANBOOT_CMD=on&LOGIN_CMD=on&embedded_script=&A=Get+Image"
  fi

  # Grab the Ubuntu 12.04 installer image
  if [[ ! -f ubuntu-12.04-mini.iso ]]; then
     #$CURL -o ubuntu-12.04-mini.iso http://archive.ubuntu.com/ubuntu/dists/precise/main/installer-amd64/current/images/netboot/mini.iso
     $CURL -o ubuntu-12.04-mini.iso http://archive.ubuntu.com/ubuntu/dists/precise-updates/main/installer-amd64/current/images/raring-netboot/mini.iso
  fi

  # Can we create the bootstrap VM via Vagrant
  if hash vagrant ; then
    echo "Vagrant detected - downloading Vagrant box for bcpc-bootstrap VM"
    if [[ ! -f precise-server-cloudimg-amd64-vagrant-disk1.box ]]; then
      $CURL -o precise-server-cloudimg-amd64-vagrant-disk1.box http://cloud-images.ubuntu.com/vagrant/precise/current/precise-server-cloudimg-amd64-vagrant-disk1.box
    fi
  fi

  popd
}

###################################################################
# Function to create the bootstrap VM
# uses Vagrant or stands-up the VM in VirtualBox for manual install
# 
function create_bootstrap_VM {
  pushd $P
  if hash vagrant ; then
    echo "Vagrant detected - using Vagrant to initialize bcpc-bootstrap VM"
    cp ../Vagrantfile .
    if [[ ! -f insecure_private_key ]]; then
      # Ensure that the private key has been created by running vagrant at least once
      vagrant status
      cp $HOME/.vagrant.d/insecure_private_key .
    fi
    vagrant up
  else
    echo "Vagrant not detected - using raw VirtualBox for bcpc-bootstrap"
    if [[ -z "WIN" ]]; then
      # Make the three BCPC networks we'll need, but clear all nets and dhcpservers first
      for i in 0 1 2 3 4 5 6 7 8 9; do
        if [[ ! -z `$VBM list hostonlyifs | grep vboxnet$i | cut -f2 -d" "` ]]; then
          $VBM hostonlyif remove vboxnet$i || true
        fi
      done
    else
      # On Windows the first interface has no number
      # The second interface is #2
      # Remove in reverse to avoid substring matching issue
      for i in 10 9 8 7 6 5 4 3 2 1; do
        if [[ i -gt 1 ]]; then
          IF="VirtualBox Host-Only Ethernet Adapter #$i";
        else
          IF="VirtualBox Host-Only Ethernet Adapter";
        fi
        if [[ ! -z `$VBM list hostonlyifs | grep "$IF"` ]]; then
          $VBM hostonlyif remove "$IF"
        fi
      done
    fi

    if [[ ! -z `$VBM list dhcpservers` ]]; then
      $VBM list dhcpservers | grep NetworkName | awk '{print $2}' | xargs -n1 $VBM dhcpserver remove --netname
    fi
  
    $VBM hostonlyif create
    $VBM hostonlyif create
    $VBM hostonlyif create
  
    if [[ -z "$WIN" ]]; then
      $VBM dhcpserver remove --ifname vboxnet0 || true
      $VBM dhcpserver remove --ifname vboxnet1 || true
      $VBM dhcpserver remove --ifname vboxnet2 || true
      # FIX: VBox 4.2.4 had dhcpserver operating without the below.
      $VBM dhcpserver remove --netname HostInterfaceNetworking-vboxnet0 || true
      $VBM dhcpserver remove --netname HostInterfaceNetworking-vboxnet1 || true
      $VBM dhcpserver remove --netname HostInterfaceNetworking-vboxnet2 || true
      # use variable names to refer to our three interfaces to disturb
      # the remaining code that refers to these as little as possible -
      # the names are compact on Unix :
      VBN0=vboxnet0
      VBN1=vboxnet1
      VBN2=vboxnet2
    else
      # However, the names are verbose on Windows :
      VBN0="VirtualBox Host-Only Ethernet Adapter"
      VBN1="VirtualBox Host-Only Ethernet Adapter #2"
      VBN2="VirtualBox Host-Only Ethernet Adapter #3"
    fi

    $VBM hostonlyif ipconfig "$VBN0" --ip 10.0.100.2    --netmask 255.255.255.0
    $VBM hostonlyif ipconfig "$VBN1" --ip 172.16.100.2  --netmask 255.255.255.0
    $VBM hostonlyif ipconfig "$VBN2" --ip 192.168.100.2 --netmask 255.255.255.0
   
    # Create bootstrap VM
    for vm in bcpc-bootstrap; do
      # Only if VM doesn't exist
      if ! $VBM list vms | grep "^\"${vm}\"" ; then
          $VBM createvm --name $vm --ostype Ubuntu_64 --basefolder $P --register
          $VBM modifyvm $vm --memory $BOOTSTRAP_VM_MEM
          $VBM modifyvm $vm --cpus $BOOTSTRAP_VM_CPUs
          $VBM storagectl $vm --name "SATA Controller" --add sata
          $VBM storagectl $vm --name "IDE Controller" --add ide
          # Create a number of hard disks
          port=0
          for disk in a; do
              $VBM createhd --filename $P/$vm/$vm-$disk.vdi --size ${BOOTSTRAP_VM_DRIVE_SIZE-20480}
              $VBM storageattach $vm --storagectl "SATA Controller" --device 0 --port $port --type hdd --medium $P/$vm/$vm-$disk.vdi
              port=$((port+1))
          done
          # Add the network interfaces
          $VBM modifyvm $vm --nic1 nat
          $VBM modifyvm $vm --nic2 hostonly --hostonlyadapter2 "$VBN0"
          $VBM modifyvm $vm --nic3 hostonly --hostonlyadapter3 "$VBN1"
          $VBM modifyvm $vm --nic4 hostonly --hostonlyadapter4 "$VBN2"
          # Add the bootable mini ISO for installing Ubuntu 12.04
          $VBM storageattach $vm --storagectl "IDE Controller" --device 0 --port 0 --type dvddrive --medium ubuntu-12.04-mini.iso
          $VBM modifyvm $vm --boot1 disk
      fi
    done
  fi
  popd
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
          $VBM createvm --name $vm --ostype Ubuntu_64 --basefolder $P --register
          $VBM modifyvm $vm --memory $CLUSTER_VM_MEM
          $VBM modifyvm $vm --cpus $CLUSTER_VM_CPUs
          $VBM storagectl $vm --name "SATA Controller" --add sata
          # Create a number of hard disks
          port=0
          for disk in a b c d e; do
              $VBM createhd --filename $P/$vm/$vm-$disk.vdi --size $CLUSTER_VM_DRIVE_SIZE
              $VBM storageattach $vm --storagectl "SATA Controller" --device 0 --port $port --type hdd --medium $P/$vm/$vm-$disk.vdi
              port=$((port+1))
          done
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

function install_cluster {
environment=${1-Test-Laptop}
ip=${2-10.0.100.3}
  # VMs are now created - if we are using Vagrant, finish the install process.
  if hash vagrant ; then
    pushd $P
    # N.B. As of Aug 2013, grub-pc gets confused and wants to prompt re: 3-way
    # merge.  Sigh.
    #vagrant ssh -c "sudo ucf -p /etc/default/grub"
    #vagrant ssh -c "sudo ucfr -p grub-pc /etc/default/grub"
    vagrant ssh -c "test -f /etc/default/grub.ucf-dist && sudo mv /etc/default/grub.ucf-dist /etc/default/grub" || true
    # Duplicate what d-i's apt-setup generators/50mirror does when set in preseed
    if [ -n "$http_proxy" ]; then
      if [ -z "`vagrant ssh -c "grep Acquire::http::Proxy /etc/apt/apt.conf"`" ]; then
        vagrant ssh -c "echo 'Acquire::http::Proxy \"$http_proxy\";' | sudo tee -a /etc/apt/apt.conf"
      fi
    fi
    popd
    echo "Bootstrap complete - setting up Chef server"
    echo "N.B. This may take approximately 30-45 minutes to complete."
    ./bootstrap_chef.sh --vagrant-remote $ip $environment
    ./enroll_cobbler.sh
  fi
}

# only execute functions if being run and not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  download_VM_files
  create_bootstrap_VM
  create_cluster_VMs
  install_cluster
fi
