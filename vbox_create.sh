#!/bin/bash -e

# bash imports
source ./virtualbox_env.sh

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

# Host-only networking configuration
readonly BCPC_IFACE_IP_MANAGEMENT="10.0.100.2"
readonly BCPC_IFACE_IP_STORAGE="172.16.100.2"
readonly BCPC_IFACE_IP_FLOAT="192.168.100.2"
readonly BCPC_IFACE_NETMASK="255.255.255.0"

# Global variables for host-only interface names
# Note that these should only be set by `create_network_interfaces`
declare BCPC_IFACE_NAME_MANAGEMENT
declare BCPC_IFACE_NAME_STORAGE
declare BCPC_IFACE_NAME_FLOAT


VBOX_DIR="`dirname ${BASH_SOURCE[0]}`/vbox"
P="$(cd $VBOX_DIR ; /bin/pwd)" || exit

# from EVW packer branch
vbm_import() {
    local -r image_name="$1"
    local -r vm_name="$2"
    shift 2
    # this currently assumes that only one virtual system is imported
    "$VBM" import "$image_name" --vsys 0 --vmname "$vm_name" "$@"
}

# Output VirtualBox host-only interfaces in machine readable format
function vbm_list_hostonlyifs {
  $VBM list hostonlyifs \
    | egrep "^(Name|IPAddress|NetworkMask):" \
    | awk '{print $2}' \
    | paste - - -
}

# Create a host-only interface and emit created interface name to stdout
function vbm_hostonlyif_create {
  $VBM hostonlyif create 2> /dev/null | egrep -o "vboxnet[[:digit:]]+"
}

function vbm_hostonlyif_ipconfig {
  local name="$1"
  local ip="$2"
  local netmask="$3"
  $VBM hostonlyif ipconfig "$name" --ip "$ip" --netmask "$netmask"
}

function create_network_interfaces {
  local name ip mask

  # find existing host-only interfaces and disable dhcp if enabled
  while read -r name ip mask; do
    local ip_found=1
    echo "$ip"
    case "$ip" in
      "$BCPC_IFACE_IP_MANAGEMENT")
        BCPC_IFACE_NAME_MANAGEMENT="$name"
        ;;
      "$BCPC_IFACE_IP_STORAGE")
        BCPC_IFACE_NAME_STORAGE="$name"
        ;;
      "$BCPC_IFACE_IP_FLOAT")
        BCPC_IFACE_NAME_FLOAT="$name"
        ;;
      *)
        unset ip_found
        ;;
    esac

    if [[ -n "$ip_found" ]]; then
      $VBM dhcpserver remove --ifname "$name"
    fi
  done < <(vbm_list_hostonlyifs)

  # if none of the host-only interfaces required are available, create them
  if [[ -z "$BCPC_IFACE_NAME_MANAGEMENT" ]]; then
    BCPC_IFACE_NAME_MANAGEMENT="$(vbm_hostonlyif_create)"
    vbm_hostonlyif_ipconfig "$BCPC_IFACE_NAME_MANAGEMENT" "$BCPC_IFACE_IP_MANAGEMENT" "$BCPC_IFACE_NETMASK"
  fi

  if [[ -z "$BCPC_IFACE_NAME_STORAGE" ]]; then
    BCPC_IFACE_NAME_STORAGE="$(vbm_hostonlyif_create)"
    vbm_hostonlyif_ipconfig "$BCPC_IFACE_NAME_STORAGE" "$BCPC_IFACE_IP_STORAGE" "$BCPC_IFACE_NETMASK"
  fi

  if [[ -z "$BCPC_IFACE_NAME_FLOAT" ]]; then
    BCPC_IFACE_NAME_FLOAT="$(vbm_hostonlyif_create)"
    vbm_hostonlyif_ipconfig "$BCPC_IFACE_NAME_FLOAT" "$BCPC_IFACE_IP_FLOAT" "$BCPC_IFACE_NETMASK"
  fi
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

  BOX='precise-server-cloudimg-amd64-vagrant-disk1.box'

  # Can we create the bootstrap VM via Vagrant
  if hash vagrant 2> /dev/null ; then
    echo "Vagrant detected - downloading Vagrant box for bcpc-bootstrap VM"
    if [[ ! -f $BOX ]]; then
	if [[ -f $CACHEDIR/$BOX ]]; then
	    cp $CACHEDIR/$BOX .
	else
	    $CURL -o precise-server-cloudimg-amd64-vagrant-disk1.box http://cloud-images.ubuntu.com/vagrant/precise/current/precise-server-cloudimg-amd64-vagrant-disk1.box
	fi
	if [[ -d $CACHEDIR && ! -f $CACHEDIR/$BOX ]]; then
	    cp $BOX $CACHEDIR
	fi
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

  if hash vagrant 2> /dev/null ; then
    echo "Vagrant detected - using Vagrant to initialize bcpc-bootstrap VM"
    cp ../Vagrantfile .
    vagrant up
    keyfile="$(vagrant ssh-config bootstrap | awk '/Host bootstrap/,/^$/{ if ($0 ~ /^ +IdentityFile/) print $2}')"
    if [[ -f "$keyfile" ]]; then
      cp "$keyfile" insecure_private_key
    fi
  else
    local -r vm="bcpc-bootstrap"
    # Only if VM doesn't exist
    if ! $VBM list vms | grep '^"${vm}"'; then
      # define this if you have a pre-built OVA image
      # (virtualbox exported machine image), for example as
      # built by
      # https://github.com/ericvw/chef-bcpc/tree/packer/bootstrap
      #ARCHIVED_BOOTSTRAP=~/bcpc-cache/packer-bcpc-bootstrap_ubuntu-12.04-amd64.ova

      if [[ -n "$ARCHIVED_BOOTSTRAP" && -f "$ARCHIVED_BOOTSTRAP" ]]; then
          vbm_import "$ARCHIVED_BOOTSTRAP" "$vm"
      else
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
          # Add the bootable mini ISO for installing Ubuntu 12.04
          $VBM storageattach $vm --storagectl "IDE Controller" --device 0 --port 0 --type dvddrive --medium ubuntu-12.04-mini.iso
          $VBM modifyvm $vm --boot1 disk
      fi
      # Add the network interfaces
      $VBM modifyvm $vm --nic1 nat
      $VBM modifyvm $vm --nic2 hostonly --hostonlyadapter2 "$BCPC_IFACE_NAME_MANAGEMENT"
      $VBM modifyvm $vm --nic3 hostonly --hostonlyadapter3 "$BCPC_IFACE_NAME_STORAGE"
      $VBM modifyvm $vm --nic4 hostonly --hostonlyadapter4 "$BCPC_IFACE_NAME_FLOAT"
    fi
  fi
  popd
}

###################################################################
# Function to create the BCPC cluster VMs
# 
function create_cluster_VMs {
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
          $VBM modifyvm $vm --nic1 hostonly --hostonlyadapter1 "$BCPC_IFACE_NAME_MANAGEMENT" --nictype1 82543GC
          $VBM setextradata $vm VBoxInternal/Devices/pcbios/0/Config/LanBootRom $P/gpxe-1.0.1-80861004.rom
          $VBM modifyvm $vm --nic2 hostonly --hostonlyadapter2 "$BCPC_IFACE_NAME_STORAGE"
          $VBM modifyvm $vm --nic3 hostonly --hostonlyadapter3 "$BCPC_IFACE_NAME_FLOAT"

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
      if ! vagrant ssh -c "grep -z Acquire::http::Proxy /etc/apt/apt.conf"; then
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
  create_network_interfaces
  create_bootstrap_VM
  create_cluster_VMs
  install_cluster $*
fi
