#!/bin/bash

# Copyright 2021, Bloomberg Finance L.P.
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

# The on_edge_flag defines whether a router should be left "connected" to
# the outside such as running DHCP and adding a masquerade source NAT rule.

set -eux

on_edge_flag=0

on_edge() {
    [[ ${on_edge_flag} == 1 ]]
}

switch_config() {
    # enable IPv4 forwarding
    sudo sed -i 's/#\(net.ipv4.ip_forward\)/\1/g' /etc/sysctl.d/99-sysctl.conf
    sudo sysctl -q -p /etc/sysctl.d/99-sysctl.conf

    if on_edge "${1}"; then
        # add masquerading source NAT rule on spines or super spines
        sudo iptables -A POSTROUTING -j MASQUERADE -o eth0 -t nat
        sudo iptables-save | sudo tee /etc/iptables/rules.v4
    fi

    # configure BIRD
    sudo cp "/vagrant/bird/${1}.conf" /etc/bird/bird.conf
    sudo systemctl restart bird
}

base_config() {
    for s in rpcbind lxcfs snapd lxd iscsid; do
        sudo systemctl stop ${s}
        sudo systemctl disable ${s}
    done
    if on_edge "${1}"; then
        ETH0_USE_ROUTES=true
    else
        ETH0_USE_ROUTES=false
    fi
    sed "s/ETH0_USE_ROUTES/${ETH0_USE_ROUTES}/" \
        "/vagrant/netplan/${1}.yaml" | sudo tee /etc/netplan/01-netcfg.yaml
    sudo netplan apply
    sudo systemctl restart lldpd
}

systemd_configuration() {
    systemctl disable systemd-resolved
    systemctl stop systemd-resolved
    rm -f /etc/resolv.conf
    nameservers=$(netplan ip leases eth0 | grep ^DNS= | sed 's/^DNS=//')
    for nameserver in ${nameservers}; do
        echo "nameserver ${nameserver}"
    done | sudo tee /etc/resolv.conf
}

apt_configuration() {
    # ref: ansible/playbooks/roles/common/tasks/configure-bgp.yml
    sudo cp "/vagrant/apt-preferences" /etc/apt/preferences.d/98-bird
}

package_installation() {
    dpkg --remove-architecture i386
    apt="sudo DEBIAN_FRONTEND=noninteractive apt-get -y"
    ${apt} update
    ${apt} install lldpd traceroute bird2 iptables-persistent
}

opts=$(getopt E "$@")
# shellcheck disable=SC2086
set -- ${opts}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -E)
            on_edge_flag=1
            shift
            ;;
        *)
            shift
            break
            ;;
    esac
done

apt_configuration
package_installation
base_config "${1}"
switch_config "${1}"
systemd_configuration
exit 0
