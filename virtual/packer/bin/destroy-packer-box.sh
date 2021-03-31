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

set -xe

packer_dir=$(dirname "$(dirname "$0")")

# Remove packer-box from vagrant box list if the packer-box exists
config_variables="${packer_dir}/variables.json"
OUTPUT_PACKER_BOX_NAME=$(jq -r '.output_packer_box_name' "$config_variables")
if [ "$OUTPUT_PACKER_BOX_NAME" == "null" ]; then
    printf "Variable \"output_packer_box_name\" in %s is undefined.\n" \
        "$config_variables"
    exit 1
fi
output_box_exists=$(vagrant box list --machine-readable \
                    | grep -i "$OUTPUT_PACKER_BOX_NAME" \
                    || true)
if [ -n "$output_box_exists" ]; then
    vagrant box remove --force --all "$OUTPUT_PACKER_BOX_NAME"
    if [ "$VAGRANT_DEFAULT_PROVIDER" == "libvirt" ]; then
        virsh vol-delete \
            --pool default \
            "${OUTPUT_PACKER_BOX_NAME}_vagrant_box_image_0.img"
        virsh pool-refresh default
    fi
fi

# Remove the output directory from packer build 
cd "$packer_dir"
if [ -d "output-vagrant" ]; then
    rm -drf output-vagrant
fi
