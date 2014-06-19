#!/bin/bash

vbox_version() {
  cat "/home/ubuntu/.vbox_version"
  return 0
}

remove_existing_guest_additions() {
  service virtualbox-guest-utils stop
  sleep 1
  modprobe -r vboxguest
  apt-get purge -y virtualbox-guest*
}

mount_guest_additions() {
  mkdir /tmp/vbox
  mount -o loop "/home/ubuntu/VBoxGuestAdditions-$(vbox_version).iso" /tmp/vbox
}

install_guest_additions() {
  sh /tmp/vbox/VBoxLinuxAdditions.run
}

umount_guest_additions() {
  umount /tmp/vbox
  rmdir /tmp/vbox
}

main() {
  remove_existing_guest_additions
  mount_guest_additions
  install_guest_additions
  umount_guest_additions
}
main
