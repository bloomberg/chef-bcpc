#!/bin/bash -x

export VAGRANT_DEFAULT_PROVIDER=libvirt
export LIBVIRT_DRIVER=qemu
sudo -E make create
sudo -E make
