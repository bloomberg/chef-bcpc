#!/bin/bash

# Copyright 2022, Bloomberg Finance L.P.
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

# Check if an official base box is added to vagrant

s3_variables="${packer_dir}/config/s3.json"
config_variables="${packer_dir}/config/variables.json"

S3_CONFIG_FILE=$(jq -r '.s3_config_file' "$s3_variables")
DOWNLOAD_BUCKET=$(jq -r '.download_bucket' "$s3_variables")
DOWNLOAD_PACKER_BOX=$(jq -r '.download_packer_box' "$s3_variables")
OUTPUT_PACKER_BOX_NAME=$(jq -r '.output_packer_box_name' "$config_variables")

if [ "$DOWNLOAD_BUCKET" == "null" ] \
   || [ "$DOWNLOAD_PACKER_BOX" == "null" ] \
   || [ "$OUTPUT_PACKER_BOX_NAME" == "null" ]; then
    printf "One or more variables in %s are undefined.\n" "$config_variables"
    exit 1
fi

#download base box from s3 storage
if [ "$S3_CONFIG_FILE" == "null" ]; then
    s3cmd get --force "${DOWNLOAD_BUCKET}/${DOWNLOAD_PACKER_BOX}" \
        "${packer_dir}/download/${DOWNLOAD_PACKER_BOX}"
else
    s3cmd -c "${S3_CONFIG_FILE}" get --force \
        "${DOWNLOAD_BUCKET}/${DOWNLOAD_PACKER_BOX}" \
        "${packer_dir}/download/${DOWNLOAD_PACKER_BOX}"
fi

# add the downloaded box as the output box in vagrant
VAGRANT_VAGRANTFILE=Vagrantfile vagrant box add \
                    --force \
                    --clean \
                    --name "$OUTPUT_PACKER_BOX_NAME" \
                    file://"${packer_dir}/download/${DOWNLOAD_PACKER_BOX}"
