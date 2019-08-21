#!/bin/bash

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

set -xe

root_dir=$(git rev-parse --show-toplevel)

virtual_dir="${root_dir}/virtual"
network_dir="${virtual_dir}/network"

if [ "${VAGRANT_DEFAULT_PROVIDER}" == "libvirt" ] ; then
    export VAGRANT_VAGRANTFILE=Vagrantfile.libvirt
fi

# bring up network nodes
(
    cd "${network_dir}"
    vagrant up
)
