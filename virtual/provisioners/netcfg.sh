#!/usr/bin/env bash

eth0_ip=$(netplan ip leases eth0 | grep -w ADDRESS | cut -d '=' -f 2)
eth1_ip=${1}
gateway=${2}

cat > /etc/netplan/01-netcfg.yaml <<EOF
---
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - ${eth0_ip}/24
EOF

cat > /etc/netplan/eth1.yaml <<EOF
---
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
        - ${eth1_ip}
      gateway4: ${gateway}
EOF

netplan apply
