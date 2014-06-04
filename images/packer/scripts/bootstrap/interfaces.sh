#!/bin/bash

cat <<EOF >> /etc/network/interfaces

# management network interface
auto eth1
iface eth1 inet static
address 10.0.100.3
netmask 255.255.255.0

# storage network interface
auto eth2
iface eth2 inet static
address 172.16.100.3
netmask 255.255.255.0

# storage network interface
auto eth3
iface eth3 inet static
address 192.168.100.3
netmask 255.255.255.0
EOF
