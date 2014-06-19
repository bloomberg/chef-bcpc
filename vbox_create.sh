#!/usr/bin/env bash

set -x

readonly DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
readonly PROGNAME="$(basename "$0")"

# bash imports
source ./virtualbox_env.sh

if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi
if [[ -z "$CURL" ]]; then
  echo "CURL is not defined"
  exit
fi


# Bootstrap VM defaults
readonly BOOTSTRAP_NODE_NAME="bcpc-bootstrap"
readonly BOOTSTRAP_PACKER_IMAGE="packer-bcpc-bootstrap_ubuntu-12.04-amd64.ova"

# Worker VM defaults
readonly WORKER_DEFAULT_NUM_VMS=3
readonly WORKER_VM_MEM=2560
readonly WORKER_VM_CPUs=2
readonly WORKER_VM_DRIVE_SIZE=20480

# Directories cache directories
readonly BCPC_CACHE_DIR=${BCPC_CACHE_DIR:-"$DIR/.cache"}
readonly DOWNLOAD_DIR="$BCPC_CACHE_DIR/downloads"
readonly VBOX_DIR="$BCPC_CACHE_DIR/vbox"

# Helper functions
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

# VirtualBox helper functions
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

# Download necessary files for VM stand-up
function download_VM_files {
  local -r ROM=gpxe-1.0.1-80861004.rom
  mkdir -p "$DOWNLOAD_DIR"
  pushd "$DOWNLOAD_DIR"

  if [[ ! -f $ROM ]]; then
    $CURL -o gpxe-1.0.1-80861004.rom "http://rom-o-matic.net/gpxe/gpxe-1.0.1/contrib/rom-o-matic/build.php" -H "Origin: http://rom-o-matic.net" -H "Host: rom-o-matic.net" -H "Content-Type: application/x-www-form-urlencoded" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Referer: http://rom-o-matic.net/gpxe/gpxe-1.0.1/contrib/rom-o-matic/build.php" -H "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3" --data "version=1.0.1&use_flags=1&ofmt=ROM+binary+%28flashable%29+image+%28.rom%29&nic=all-drivers&pci_vendor_code=8086&pci_device_code=100E&PRODUCT_NAME=&PRODUCT_SHORT_NAME=gPXE&CONSOLE_PCBIOS=on&BANNER_TIMEOUT=20&NET_PROTO_IPV4=on&COMCONSOLE=0x3F8&COMSPEED=115200&COMDATA=8&COMPARITY=0&COMSTOP=1&DOWNLOAD_PROTO_TFTP=on&DNS_RESOLVER=on&NMB_RESOLVER=off&IMAGE_ELF=on&IMAGE_NBI=on&IMAGE_MULTIBOOT=on&IMAGE_PXE=on&IMAGE_SCRIPT=on&IMAGE_BZIMAGE=on&IMAGE_COMBOOT=on&AUTOBOOT_CMD=on&NVO_CMD=on&CONFIG_CMD=on&IFMGMT_CMD=on&IWMGMT_CMD=on&ROUTE_CMD=on&IMAGE_CMD=on&DHCP_CMD=on&SANBOOT_CMD=on&LOGIN_CMD=on&embedded_script=&A=Get+Image"
  fi

  local -r ISO=ubuntu-12.04-mini.iso
  # Grab the Ubuntu 12.04 installer image
  if [[ ! -f  $ISO ]]; then
    #$CURL -o ubuntu-12.04-mini.iso http://archive.ubuntu.com/ubuntu/dists/precise/main/installer-amd64/current/images/netboot/mini.iso
    $CURL -o $ISO http://archive.ubuntu.com/ubuntu/dists/precise-updates/main/installer-amd64/current/images/raring-netboot/mini.iso
  fi

  popd
}


# Use Packer to build the bcpc-bootstrap VM if the image is not available.
create_bootstrap_vm() {
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
    # TODO(ericvw): make port forwarding smarter about chosen host port
    "$VBM" modifyvm "$BOOTSTRAP_NODE_NAME" --natpf1 ssh,tcp,,2323,,22
  fi
}


# Create worker VMs to be used as head and compute nodes
create_worker_vms() {
  local -r num_vms="${1:-"$WORKER_DEFAULT_NUM_VMS"}"
  local -r disk_suffixes=({a..e})

  # Create each VM
  local vmIdx
  for ((vmIdx = 1; vmIdx <= "$num_vms"; vmIdx++)); do
    local vm="bcpc-vm$vmIdx"
    if vm_exists "$vm"; then
      continue
    fi

    $VBM createvm --name $vm --ostype Ubuntu_64 --basefolder "$VBOX_DIR" --register
    $VBM modifyvm $vm --memory "$WORKER_VM_MEM"
    $VBM modifyvm $vm --cpus "$WORKER_VM_CPUs"
    $VBM storagectl $vm --name "SATA Controller" --add sata

    # Create a number of hard disks
    local diskIdx
    for diskIdx in "${!disk_suffixes[@]}"; do
      local disk="${disk_suffixes[$diskIdx]}"
      local port=$((diskIdx + 1))
      $VBM createhd --filename "$VBOX_DIR/$vm/disk-$disk.vdi" --size "$WORKER_VM_DRIVE_SIZE"
      $VBM storageattach $vm --storagectl "SATA Controller" --device 0 --port "$port" --type hdd --medium "$VBOX_DIR/$vm/disk-$disk.vdi"
    done

    $VBM setextradata $vm VBoxInternal/Devices/pcbios/0/Config/LanBootRom $DOWNLOAD_DIR/gpxe-1.0.1-80861004.rom

    # Add the network interfaces
    $VBM modifyvm $vm --nic1 intnet --intnet1 bcpc-management
    $VBM modifyvm $vm --nic2 intnet --intnet2 bcpc-storage
    $VBM modifyvm $vm --nic3 intnet --intnet3 bcpc-float

    # setup boot order
    $VBM modifyvm $vm --boot1 net
    $VBM modifyvm $vm --boot2 disk
    $VBM modifyvm $vm --boot3 none
    $VBM modifyvm $vm --boot2 none

    # Set hardware acceleration options
    $VBM modifyvm $vm --largepages on --vtxvpid on --hwvirtex on --nestedpaging on --ioapic on
  done
}


# Start the bcpc-bootstrap VM
start_bootstrap_vm() {
  if ! vm_running "$BOOTSTRAP_NODE_NAME"; then
    vbm_startvm bcpc-bootstrap
  fi
}


# Provision the bcpc-bootstrap node with Chef and converge itself
provision_bootstrap_node() {
  local -r environment=${1-Test-Laptop}
  local -r ip=${2-10.0.100.3}
  local -r ssh_config="$BCPC_CACHE_DIR/dev/ssh_config"
  mkdir -p "$(dirname "$ssh_config")"

  local -r id_rsa_dest="$BCPC_CACHE_DIR/dev/id_rsa"
  cp images/packer/files/id_rsa "$id_rsa_dest"

  cat <<-EOF >> "$ssh_config"
Host bcpc-bootstrap
GSSAPIAuthentication no
HostName localhost
IdentityFile $id_rsa_dest
Port 2323
StrictHostKeyChecking no
User ubuntu
UserKnownHostsFile /dev/null
EOF

  echo "Bootstrap complete - setting up Chef server"
  echo "N.B. This may take approximately 30-45 minutes to complete."
  ./bootstrap_chef.sh "$ssh_config" "$ip" "$environment"
  ./enroll_cobbler.sh "$ssh_config"
}


# Main
main() {
  download_VM_files
  create_bootstrap_vm
  create_worker_vms
  start_bootstrap_vm
  provision_bootstrap_node "$@"
}
main
