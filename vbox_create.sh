#!/bin/bash -e

set -x

if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi

if [[ -z "$CURL" ]]; then
  echo "CURL is not defined"
  exit
fi

VBM=VBoxManage
DRIVE_SIZE=20480

DIR=`dirname $0`/vbox

pushd $DIR

P=`python -c "import os.path; print os.path.abspath('./')"`

if [[ ! -f gpxe-1.0.1-80861004.rom ]]; then
  $CURL -o gpxe-1.0.1-80861004.rom "http://rom-o-matic.net/gpxe/gpxe-1.0.1/contrib/rom-o-matic/build.php" -H "Origin: http://rom-o-matic.net" -H "Host: rom-o-matic.net" -H "Content-Type: application/x-www-form-urlencoded" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Referer: http://rom-o-matic.net/gpxe/gpxe-1.0.1/contrib/rom-o-matic/build.php" -H "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3" --data "version=1.0.1&use_flags=1&ofmt=ROM+binary+%28flashable%29+image+%28.rom%29&nic=all-drivers&pci_vendor_code=8086&pci_device_code=1004&PRODUCT_NAME=&PRODUCT_SHORT_NAME=gPXE&CONSOLE_PCBIOS=on&BANNER_TIMEOUT=20&NET_PROTO_IPV4=on&COMCONSOLE=0x3F8&COMSPEED=115200&COMDATA=8&COMPARITY=0&COMSTOP=1&DOWNLOAD_PROTO_TFTP=on&DNS_RESOLVER=on&NMB_RESOLVER=off&IMAGE_ELF=on&IMAGE_NBI=on&IMAGE_MULTIBOOT=on&IMAGE_PXE=on&IMAGE_SCRIPT=on&IMAGE_BZIMAGE=on&IMAGE_COMBOOT=on&AUTOBOOT_CMD=on&NVO_CMD=on&CONFIG_CMD=on&IFMGMT_CMD=on&IWMGMT_CMD=on&ROUTE_CMD=on&IMAGE_CMD=on&DHCP_CMD=on&SANBOOT_CMD=on&LOGIN_CMD=on&embedded_script=&A=Get+Image"
fi

# Grab the Ubuntu 12.04 installer image
if [[ ! -f ubuntu-12.04-mini.iso ]]; then
    $CURL -o ubuntu-12.04-mini.iso http://archive.ubuntu.com/ubuntu/dists/precise/main/installer-amd64/current/images/netboot/mini.iso
fi

if ! hash $VBM ; then
  echo "You do not appear to have $VBM from VirtualBox"
  exit 1
fi

# Can we create the bootstrap VM via Vagrant
if hash vagrant ; then
  echo "Vagrant detected - using Vagrant to initialize bcpc-bootstrap"
  echo "N.B. This may take approximately 30-45 minutes to complete."
  if [[ ! -f precise-server-cloudimg-amd64-vagrant-disk1.box ]]; then
    $CURL -o precise-server-cloudimg-amd64-vagrant-disk1.box http://cloud-images.ubuntu.com/vagrant/precise/current/precise-server-cloudimg-amd64-vagrant-disk1.box
  fi
  cp ../Vagrantfile .
  if [[ ! -f insecure_private_key ]]; then
    # Ensure that the private key has been created by running vagrant at least once
    vagrant -v
    cp $HOME/.vagrant.d/insecure_private_key .
  fi
  vagrant up
else
  echo "Vagrant not detected - using raw VirtualBox for bcpc-bootstrap"
  # Make the three BCPC networks we'll need, but clear all nets and dhcpservers first
  for i in 0 1 2 3 4 5 6 7 8 9; do
    if [[ ! -z `$VBM list hostonlyifs | grep vboxnet$i | cut -f2 -d" "` ]]; then
      $VBM hostonlyif remove vboxnet$i || true
    fi
  done

  if [[ ! -z `$VBM list dhcpservers` ]]; then
    $VBM list dhcpservers | grep NetworkName | awk '{print $2}' | xargs -n1 $VBM dhcpserver remove --netname
  fi
  $VBM hostonlyif create
  $VBM hostonlyif create
  $VBM hostonlyif create
  $VBM dhcpserver remove --ifname vboxnet0 || true
  $VBM dhcpserver remove --ifname vboxnet1 || true
  $VBM dhcpserver remove --ifname vboxnet2 || true
  # FIX: VBox 4.2.4 had dhcpserver operating without the below.
  $VBM dhcpserver remove --netname HostInterfaceNetworking-vboxnet0 || true
  $VBM dhcpserver remove --netname HostInterfaceNetworking-vboxnet1 || true
  $VBM dhcpserver remove --netname HostInterfaceNetworking-vboxnet2 || true
  $VBM hostonlyif ipconfig vboxnet0 --ip 10.0.100.2 --netmask 255.255.255.0
  $VBM hostonlyif ipconfig vboxnet1 --ip 172.16.100.2 --netmask 255.255.255.0
  $VBM hostonlyif ipconfig vboxnet2 --ip 192.168.100.2 --netmask 255.255.255.0
  # Create bootstrap VM
  for vm in bcpc-bootstrap; do
    # Only if VM doesn't exist
    if ! $VBM list vms | grep "^\"${vm}\"" ; then
        $VBM createvm --name $vm --ostype Ubuntu_64 --basefolder $P --register
        $VBM modifyvm $vm --memory 1024
        $VBM storagectl $vm --name "SATA Controller" --add sata
        $VBM storagectl $vm --name "IDE Controller" --add ide
        # Create a number of hard disks
        port=0
        for disk in a; do
            $VBM createhd --filename $P/$vm/$vm-$disk.vdi --size $DRIVE_SIZE
            $VBM storageattach $vm --storagectl "SATA Controller" --device 0 --port $port --type hdd --medium $P/$vm/$vm-$disk.vdi
            port=$((port+1))
        done
        # Add the network interfaces
        $VBM modifyvm $vm --nic1 nat
        $VBM modifyvm $vm --nic2 hostonly --hostonlyadapter2 vboxnet0
        $VBM modifyvm $vm --nic3 hostonly --hostonlyadapter3 vboxnet1
        $VBM modifyvm $vm --nic4 hostonly --hostonlyadapter4 vboxnet2
        # Add the bootable mini ISO for installing Ubuntu 12.04
        $VBM storageattach $vm --storagectl "IDE Controller" --device 0 --port 0 --type dvddrive --medium ubuntu-12.04-mini.iso
        $VBM modifyvm $vm --boot1 disk
    fi
  done
fi

# Create each VM
for vm in bcpc-vm1 bcpc-vm2 bcpc-vm3; do
    # Only if VM doesn't exist
    if ! $VBM list vms | grep "^\"${vm}\"" ; then
        $VBM createvm --name $vm --ostype Ubuntu_64 --basefolder $P --register
        $VBM modifyvm $vm --memory 2048
        $VBM storagectl $vm --name "SATA Controller" --add sata
        # Create a number of hard disks
        port=0
        for disk in a b c d e; do
            $VBM createhd --filename $P/$vm/$vm-$disk.vdi --size $DRIVE_SIZE
            $VBM storageattach $vm --storagectl "SATA Controller" --device 0 --port $port --type hdd --medium $P/$vm/$vm-$disk.vdi
            port=$((port+1))
        done
        # Add the network interfaces
        $VBM modifyvm $vm --nic1 hostonly --hostonlyadapter1 vboxnet0 --nictype1 82543GC
        $VBM setextradata $vm VBoxInternal/Devices/pcbios/0/Config/LanBootRom $P/gpxe-1.0.1-80861004.rom
        $VBM modifyvm $vm --nic2 hostonly --hostonlyadapter2 vboxnet1
        $VBM modifyvm $vm --nic3 hostonly --hostonlyadapter3 vboxnet2
        #$VBM modifyvm $vm --largepages on --vtxvpid on --hwvirtexexcl on
    fi
done

popd
