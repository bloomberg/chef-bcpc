#!/bin/bash

# Copyright 2020, Bloomberg Finance L.P.
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

set -xe

root_dir=$(git rev-parse --show-toplevel)

virtual_dir="${root_dir}/virtual"
ansible_dir="${root_dir}/ansible"
files_dir="${virtual_dir}/files"

ssh_dir="${files_dir}/ssh"
ssh_key_type="ed25519"
ssh_private_key_file="${ssh_dir}/id_${ssh_key_type}"

topology_file="${virtual_dir}/topology/topology.yml"
topology_overrides_file="${virtual_dir}/topology/topology.overrides.yml"
ssh_config_file=$(mktemp)

if [ -f "${topology_overrides_file}" ]; then
    topology_file=${topology_overrides_file}
fi

if [ "${VAGRANT_DEFAULT_PROVIDER}" == "libvirt" ] ; then
    export VAGRANT_VAGRANTFILE=Vagrantfile.libvirt
fi

# generate operations ssh key pair
(
    cd "${virtual_dir}"
    mkdir -p "${ssh_dir}"

    if [ ! -e "${ssh_private_key_file}" ]; then
        ssh-keygen \
            -t "${ssh_key_type}" \
            -f "${ssh_private_key_file}" \
            -C '' \
            -N ''
    fi
)

# bring up vagrant/virtualbox nodes
(
    cd "${virtual_dir}"
    vagrant up --parallel

    # export ssh config file for ansible inventory parsing
    vagrant ssh-config > "${ssh_config_file}"
)

# generate virtual cloud ansible inventory files
"${virtual_dir}/bin/generate-ansible-inventory.py" \
    --ssh-config "${ssh_config_file}" \
    --topology-config "${topology_file}" > "${ansible_dir}/inventory.yml"

# reboot vms to load new kernel
ansible -i "${ansible_dir}/inventory.yml" cloud -b -B 1 -P 0 -m shell -a "sleep 5 && reboot"
ansible -i "${ansible_dir}/inventory.yml" cloud -m wait_for_connection -a "delay=15"
