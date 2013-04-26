#!/bin/bash -e

set -x

export HTTP_PROXY=
export HTTPS_PROXY=

VBM=/usr/bin/VBoxManage
DRIVE_SIZE=20480

DIR=`dirname $0`/vbox

pushd $DIR

P=`python -c "import os.path; print os.path.abspath('./')"`

# Grab the Ubuntu 12.04 installer image
if [ ! -f ubuntu-12.04-mini.iso ]; then
    curl -o ubuntu-12.04-mini.iso http://archive.ubuntu.com/ubuntu/dists/precise/main/installer-amd64/current/images/netboot/mini.iso
fi

# Make the three BCPC networks we'll need
for i in 0 1 2 3 4 5 6 7 8 9; do
    $VBM hostonlyif remove vboxnet$i || true
done
$VBM hostonlyif create
$VBM hostonlyif create
$VBM hostonlyif create
$VBM dhcpserver remove --ifname vboxnet0 || true
$VBM dhcpserver remove --ifname vboxnet1 || true
$VBM dhcpserver remove --ifname vboxnet2 || true
$VBM hostonlyif ipconfig vboxnet0 --ip 10.0.100.2 --netmask 255.255.255.0
$VBM hostonlyif ipconfig vboxnet1 --ip 172.16.100.2 --netmask 255.255.255.0
$VBM hostonlyif ipconfig vboxnet2 --ip 192.168.100.2 --netmask 255.255.255.0
# Create each VM
for vm in bcpc-vm1 bcpc-vm2 bcpc-vm3; do
    # Only if VM doesn't exist
    if ! $VBM list vms | grep $vm ; then
        $VBM createvm --name $vm --ostype Ubuntu_64 --basefolder $P --register
        $VBM modifyvm $vm --memory 2048
        $VBM storagectl $vm --name "SATA Controller" --add sata
        $VBM storagectl $vm --name "IDE Controller" --add ide
        # Create a number of hard disks
        port=0
        for disk in a b c d e; do
            $VBM createhd --filename $P/$vm/$vm-$disk.vdi --size $DRIVE_SIZE
            $VBM storageattach $vm --storagectl "SATA Controller" --device 0 --port $port --type hdd --medium $P/$vm/$vm-$disk.vdi
            port=$((port+1))
        done
        # Add the network interfaces
        $VBM modifyvm $vm --nic1 hostonly --hostonlyadapter1 vboxnet0
        $VBM modifyvm $vm --nic2 hostonly --hostonlyadapter2 vboxnet1
        $VBM modifyvm $vm --nic3 hostonly --hostonlyadapter3 vboxnet2
        # Add the bootable mini ISO for installing Ubuntu 12.04
        $VBM storageattach $vm --storagectl "IDE Controller" --device 0 --port 0 --type dvddrive --medium ubuntu-12.04-mini.iso
    fi
done

popd
