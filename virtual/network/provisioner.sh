#!/bin/bash -x

# Copyright 2019, Bloomberg Finance L.P.
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

COMMON_PKGS="lldpd traceroute"
SWITCH_PKGS="bird iptables-persistent"

is_tor() {
  [[ ${1} =~ ^tor ]]
}

is_spine() {
  [[ ${1} =~ ^spine ]]
}

apt_get="sudo DEBIAN_FRONTEND=noninteractive apt-get -y"

switch_config() {
    # enable ipv4 forwarding
    sudo sed -i 's/#\(net.ipv4.ip_forward\)/\1/g' /etc/sysctl.d/99-sysctl.conf
    sudo sysctl -q -p /etc/sysctl.d/99-sysctl.conf

    if is_spine ${1} ; then
        # add masquerading source NAT rule on spines
        sudo iptables -A POSTROUTING -j MASQUERADE -o eth0 -t nat
        sudo iptables-save | sudo tee /etc/iptables/rules.v4
    fi

    # configure BIRD
    sudo cp /vagrant/bird/${1}.conf /etc/bird/bird.conf
    sudo systemctl restart bird
}

common_config() {
    for s in rpcbind lxcfs snapd lxd iscsid ; do
        sudo systemctl stop ${s}
        sudo systemctl disable ${s}
    done
    sudo cp /vagrant/netplan/${1}.yaml /etc/netplan/01-netcfg.yaml
    # stop dhclient on the TORs as netplan(5) doesn't
    is_tor ${1} && dhclient -x
    sudo netplan apply
    sudo systemctl restart lldpd
}

ADDITIONAL_PKGS=${COMMON_PKGS}
is_spine ${1} || is_tor ${1} && \
  ADDITIONAL_PKGS="${ADDITIONAL_PKGS} ${SWITCH_PKGS}"
${apt_get} update
${apt_get} install ${ADDITIONAL_PKGS}

common_config ${1}
is_spine ${1} || is_tor ${1} && switch_config ${1}

exit 0
