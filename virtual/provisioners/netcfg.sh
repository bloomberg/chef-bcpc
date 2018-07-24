#!/usr/bin/env bash

# Copyright 2018, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

eth1_ip=${1}
gateway=${2}

if netplan ip leases eth0 > /dev/null 2>&1; then
  eth0_ip=$(netplan ip leases eth0 | grep -w ADDRESS | cut -d '=' -f 2)

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
fi


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
