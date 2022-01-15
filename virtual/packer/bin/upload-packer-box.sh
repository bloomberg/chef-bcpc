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

S3_CONFIG_FILE=$(jq -r '.s3_config_file' "$s3_variables")
OUTPUT_PACKER_BOX_NAME=$(jq -r '.output_packer_box_name' "$s3_variables")
UPLOAD_BUCKET=$(jq -r '.upload_bucket' "$s3_variables")
UPLOAD_SOURCE_PACKER_BOX=$(jq -r '.upload_source_packer_box' "$s3_variables")
UPLOAD_TARGET_PACKER_BOX=$(jq -r '.upload_target_packer_box' "$s3_variables")

if [ "$UPLOAD_BUCKET" == "null" ] \
   || [ "$UPLOAD_SOURCE_PACKER_BOX" == "null" ] \
   || [ "$UPLOAD_TARGET_PACKER_BOX" == "null" ]; then
    printf "One or more variables in %s are undefined.\n" "$s3_variables"
    exit 1
fi

#upload base box from s3 storage
if [ "$S3_CONFIG_FILE" == "null" ]; then
    s3cmd put --force "${packer_dir}/${UPLOAD_SOURCE_PACKER_BOX}" "${UPLOAD_BUCKET}/${UPLOAD_TARGET_PACKER_BOX}"
else
    s3cmd -c "${S3_CONFIG_FILE}" put --force "${packer_dir}/${UPLOAD_SOURCE_PACKER_BOX}" "${UPLOAD_BUCKET}/${UPLOAD_TARGET_PACKER_BOX}"
fi

