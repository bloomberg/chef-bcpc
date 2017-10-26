#!/bin/bash
ENP0S3="# The primary network interface
auto enp0s3
iface enp0s3 inet static
  address 10.0.2.15
  netmask 255.255.255.0
"

echo "$ENP0S3" > /etc/network/interfaces.d/enp0s3.cfg

if pgrep dhclient; then
  killall -TERM dhclient
fi

if ip route | grep -q 'default via 10.0.2.2'; then
  ip route del default via 10.0.2.2
fi
