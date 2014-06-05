#!/bin/bash -e

# bash imports
source ./virtualbox_env.sh

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

# Bootstrap VM Defaults (these need to be exported for Vagrant's Vagrantfile)
export BOOTSTRAP_VM_MEM=1536
export BOOTSTRAP_VM_CPUs=1
# Use this if you intend to make an apt-mirror in this VM (see the
# instructions on using an apt-mirror towards the end of bootstrap.md)
# -- Vagrant VMs do not use this size --
#BOOTSTRAP_VM_DRIVE_SIZE=120480

# Cluster VM Defaults
CLUSTER_VM_MEM=2560
CLUSTER_VM_CPUs=2
CLUSTER_VM_DRIVE_SIZE=20480

readonly BOOTSTRAP_NODE_NAME="bcpc-bootstrap"
readonly BOOTSTRAP_PACKER_IMAGE="packer-bcpc-bootstrap_ubuntu-12.04-amd64.ova"

readonly DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
readonly CMD="$(basename "$0")"

VBOX_DIR="$DIR/vbox"
P="$VBOX_DIR"

command_exists() {
  local -r cmd="$1"
  command -v "$cmd" > /dev/null
}

command_exists_or_exit() {
  local -r cmd="$1"
  if ! command_exists "$cmd"; then
    echo "$CMD: $cmd not in PATH"
    exit 1
  fi
}

vbm_list_vms() {
  "$VBM" list vms | awk '{print $1}' | sed 's/"//g'
}

vbm_list_runningvms() {
  "$VBM" list runningvms | awk '{print $1}' | sed 's/"//g'
}

vbm_import() {
  local -r image_name="$1"
  local -r vm_name="$2"
  shift 2
  # this currently assumes that only one virtual system is imported
  "$VBM" import "$image_name" --vsys 0 --vmname "$vm_name" "$@"
}

vbm_startvm() {
  local -r uiid_or_vmname="$1"
  shift
  "$VBM" startvm "$uiid_or_vmname" "$@"
}

vm_exists() {
  local -r vm="$1"
  vbm_list_vms | grep -q "$vm"
}

vm_running() {
  local -r vm="$1"
  vbm_list_runningvms | grep -q "$vm"
}

######################################################
# Function to download files necessary for VM stand-up
# 
function download_VM_files {
  pushd $P

  ROM=gpxe-1.0.1-80861004.rom
  CACHEDIR=~/bcpc-cache

  if [[ ! -f $ROM ]]; then
      if [[ -f $CACHEDIR/$ROM ]]; then
	  cp $CACHEDIR/$ROM .
      else
	  $CURL -o gpxe-1.0.1-80861004.rom "http://rom-o-matic.net/gpxe/gpxe-1.0.1/contrib/rom-o-matic/build.php" -H "Origin: http://rom-o-matic.net" -H "Host: rom-o-matic.net" -H "Content-Type: application/x-www-form-urlencoded" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Referer: http://rom-o-matic.net/gpxe/gpxe-1.0.1/contrib/rom-o-matic/build.php" -H "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3" --data "version=1.0.1&use_flags=1&ofmt=ROM+binary+%28flashable%29+image+%28.rom%29&nic=all-drivers&pci_vendor_code=8086&pci_device_code=1004&PRODUCT_NAME=&PRODUCT_SHORT_NAME=gPXE&CONSOLE_PCBIOS=on&BANNER_TIMEOUT=20&NET_PROTO_IPV4=on&COMCONSOLE=0x3F8&COMSPEED=115200&COMDATA=8&COMPARITY=0&COMSTOP=1&DOWNLOAD_PROTO_TFTP=on&DNS_RESOLVER=on&NMB_RESOLVER=off&IMAGE_ELF=on&IMAGE_NBI=on&IMAGE_MULTIBOOT=on&IMAGE_PXE=on&IMAGE_SCRIPT=on&IMAGE_BZIMAGE=on&IMAGE_COMBOOT=on&AUTOBOOT_CMD=on&NVO_CMD=on&CONFIG_CMD=on&IFMGMT_CMD=on&IWMGMT_CMD=on&ROUTE_CMD=on&IMAGE_CMD=on&DHCP_CMD=on&SANBOOT_CMD=on&LOGIN_CMD=on&embedded_script=&A=Get+Image"
	      
      fi
      if [[ -d $CACHEDIR && ! -f $CACHEDIR/$ROM ]]; then
	  cp $ROM $CACHEDIR/$ROM
      fi
  fi

  ISO=ubuntu-12.04-mini.iso

  # Grab the Ubuntu 12.04 installer image
  if [[ ! -f  $ISO ]]; then
      if [[ -f $CACHEDIR/$ISO ]]; then
	  cp $CACHEDIR/$ISO .
      else
     #$CURL -o ubuntu-12.04-mini.iso http://archive.ubuntu.com/ubuntu/dists/precise/main/installer-amd64/current/images/netboot/mini.iso
	  $CURL -o $ISO http://archive.ubuntu.com/ubuntu/dists/precise-updates/main/installer-amd64/current/images/raring-netboot/mini.iso
      fi
      if [[ -d $CACHEDIR && ! -f $CACHEDIR/$ISO ]]; then
	  cp $ISO $CACHEDIR
      fi
  fi

  popd
}


# Use Packer to build the bcpc-bootstrap VM if the image is not available.
create_bootstrap_vm() {
  local -r ERREXIT="$(set +o | grep errexit)"
  set +o errexit

  if ! vm_exists bcpc-bootstrap; then
    local -r images_dir="$DIR/images"
    local -r image="$images_dir/build/virtualbox/bcpc-bootstrap/$BOOTSTRAP_PACKER_IMAGE"

    if [[ ! -f "$image" ]]; then
      command_exists_or_exit packer
      local -r packer_dir="$images_dir/packer"
      pushd "$packer_dir"
      packer build bcpc-bootstrap.json
      popd
    fi

    vbm_import "$image" "$BOOTSTRAP_NODE_NAME"
  fi

  # restore errexit
  $ERREXIT
}


# Start the bcpc-bootstrap VM
start_bootstrap_vm() {
  if ! vm_running "$BOOTSTRAP_NODE_NAME"; then
    vbm_startvm bcpc-bootstrap
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
  if hash vagrant 2> /dev/null ; then
    pushd $P
    # N.B. As of Aug 2013, grub-pc gets confused and wants to prompt re: 3-way
    # merge.  Sigh.
    #vagrant ssh -c "sudo ucf -p /etc/default/grub"
    #vagrant ssh -c "sudo ucfr -p grub-pc /etc/default/grub"
    vagrant ssh -c "test -f /etc/default/grub.ucf-dist && sudo mv /etc/default/grub.ucf-dist /etc/default/grub" || true
    # Duplicate what d-i's apt-setup generators/50mirror does when set in preseed
    if [ -n "$http_proxy" ]; then
      if [ -z `vagrant ssh -c "grep Acquire::http::Proxy /etc/apt/apt.conf"` ]; then
        vagrant ssh -c "echo 'Acquire::http::Proxy \"$http_proxy\";' | sudo tee -a /etc/apt/apt.conf"
      fi
    fi
    popd
    echo "Bootstrap complete - setting up Chef server"
    echo "N.B. This may take approximately 30-45 minutes to complete."
    ./bootstrap_chef.sh --vagrant-remote $ip $environment
    ./enroll_cobbler.sh
  else
      ./non_vagrant_boot.sh
  fi
}

# only execute functions if being run and not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  download_VM_files
  create_bootstrap_vm
  start_bootstrap_vm
  create_cluster_VMs
  install_cluster $*
fi
