#!/bin/bash

# Copyright 2023, Bloomberg Finance L.P.
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

packer_dir=$(dirname "$(dirname "$0")")
os_config_variables="${packer_dir}/config/variables.json"

for OS_RELEASE in $(jq -r '. | keys[]' "${os_config_variables}"); do
    PACKER_BOX_NAME=$(jq -r ".[\"${OS_RELEASE}\"].output_packer_box_name" \
        "${os_config_variables}")

    # Remove packer-box from vagrant box list if the packer-box exists
    if [ "$PACKER_BOX_NAME" == "null" ]; then
        printf "Variable \"output_packer_box_name\" in %s is undefined.\n" \
            "$os_config_variables for key ${OS_RELEASE}"
        exit 1
    fi
    output_box_exists=$(vagrant box list --machine-readable \
                        | grep -i "$PACKER_BOX_NAME" \
                        || true)
    if [ -n "$output_box_exists" ]; then
        vagrant box remove --force --all "$PACKER_BOX_NAME"
        if [ "$VAGRANT_DEFAULT_PROVIDER" == "libvirt" ]; then
            virsh vol-delete \
                --pool default \
                "${PACKER_BOX_NAME}_vagrant_box_image_0_box.img" || true
            virsh pool-refresh default
        fi
    fi

    # cleanup any scrapnel vagrant-libvirt may have left lying around
    if [ "$VAGRANT_DEFAULT_PROVIDER" == "libvirt" ]; then
        virsh destroy output-vagrant_source || true
        virsh undefine output-vagrant_source || true
        virsh vol-delete --pool default output-vagrant_source.img || true
    fi

    # Remove the output directory from packer build
    pushd "$packer_dir"
    if [ -d "output-vagrant" ] || [ -d "output-vagrant-${OS_RELEASE}" ]; then
        rm -drf output-vagrant "output-vagrant-${OS_RELEASE}"
    fi
    popd
done
