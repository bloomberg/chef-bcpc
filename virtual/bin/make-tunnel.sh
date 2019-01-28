#!/bin/bash -e

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

env=virtual
root_dir=$(git rev-parse --show-toplevel)
virtual_dir=${root_dir}/${env}
bootstrap=r1n0

cd ${virtual_dir}

vip=$(vagrant ssh r1n0 -c "sudo -u operations -i -- sh -c 'knife environment show virtual -a override_attributes.bcpc.cloud.vip' | tail -n 1 | awk '{ print \$2 }'")

if [ -z "${vip}" ]; then
    echo "Error creating tunnel: VIP not found"
    exit 1
fi

echo
echo 'Horizon: https://127.0.0.1:8443/horizon/'
echo

ssh_tunnel_conf=/tmp/ssh-config.$$
vagrant ssh-config ${bootstrap} > ${ssh_tunnel_conf}
ssh -C -F ${ssh_tunnel_conf} \
    -L 8443:${vip}:443 \
    -L 6080:${vip}:6080 \
    ${bootstrap}
rm ${ssh_tunnel_conf}
