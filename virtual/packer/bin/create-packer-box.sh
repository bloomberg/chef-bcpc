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
    # Generate configuration variables for this OS release
    config_variables=$(mktemp -t variables-XXXXXXX.json)
    jq -r ".[\"${OS_RELEASE}\"]" "${os_config_variables}" \
        > "${config_variables}"

    # Check if an official base box is added to vagrant
    BASE_BOX=$(jq -r '.base_box' "${config_variables}")
    BASE_BOX_VERSION=$(jq -r '.base_box_version' "${config_variables}")
    BASE_BOX_PROVIDER=$(jq -r '.base_box_provider' "${config_variables}")
    VAGRANT_CACERT=$(jq -r '.vagrant_cacert' "${config_variables}")
    PACKER_BOX_NAME=$(jq -r '.output_packer_box_name' "${config_variables}")

    # Set the environment variable VAGRANT_DEFAULT_PROVIDER to
    # match BASE_BOX_PROVIDER on the variables.json file
    export VAGRANT_DEFAULT_PROVIDER="$BASE_BOX_PROVIDER"

    if [ "$BASE_BOX" == "null" ] \
        || [ "$BASE_BOX_VERSION" == "null" ] \
        || [ "$PACKER_BOX_NAME" == "null" ]; then
        printf "Variable(s) in %s are undefined.\n" "$config_variables"
        exit 1
    fi
    base_box_exists=$(
        vagrant box list --machine-readable |
        grep -i "${BASE_BOX}.*${BASE_BOX_PROVIDER}.*${BASE_BOX_VERSION}" \
        || true
    )
    if [ -z "$base_box_exists" ]; then
        CURL_CA_BUNDLE=${VAGRANT_CACERT:+$VAGRANT_CACERT} vagrant box add \
            --box-version "$BASE_BOX_VERSION" \
            --force \
            --provider virtualbox \
            "$BASE_BOX"
        if [ "$BASE_BOX_PROVIDER" == "libvirt" ]; then
            printf "Checking for vagrant mutate"
            mutate=$(vagrant plugin list | grep mutate)
            if [ -z "$mutate" ]; then
                printf "Vagrant mutate not found. "
                printf "Install vagrant-mutate to allow base conversion\n"
                exit 1
            else
                printf "Vagrant mutate found, mutating VirtualBox version\n"
                vagrant mutate "${BASE_BOX}" --input-provider virtualbox \
                    libvirt
            fi
        fi
    fi

    # prevent vagrant-libvirt from failing if there's scrapnel lying around
    if [ "$VAGRANT_DEFAULT_PROVIDER" == "libvirt" ]; then
        virsh destroy output-vagrant_source || true
        virsh undefine output-vagrant_source || true
        virsh vol-delete --pool default output-vagrant_source.img || true
        virsh pool-refresh default
    fi

    # create the packer box
    # Use the script path to find the packer directory
    pushd "$packer_dir"
    if ! command -v "packer" &> /dev/null; then
        printf "Command packer not found. Please check if it is installed.\n"
        exit 1
    fi
    if [ -d "output-vagrant" ] || [ -d "output-vagrant-${OS_RELEASE}" ]; then
        rm -drf output-vagrant "output-vagrant-${OS_RELEASE}"
    fi
    current_packer_ver=$(packer --version)
    required_packer_ver="1.4.0"
    lower_packer_ver=$(printf '%s\n' "$required_packer_ver" \
                                    "$current_packer_ver" \
                        | sort -V \
                        | head -n1)
    if [ "$lower_packer_ver" = "$required_packer_ver" ]; then
        VAGRANT_VAGRANTFILE=Vagrantfile packer build \
                            --force \
                            --on-error=abort \
                            --var-file="${config_variables}" \
                            "config/config.json"
        mv "output-vagrant" "output-vagrant-${OS_RELEASE}"
        cd "output-vagrant-${OS_RELEASE}"
        VAGRANT_VAGRANTFILE=Vagrantfile vagrant box add \
                            --force \
                            --clean \
                            --name "$PACKER_BOX_NAME" \
                            file://package.box
    else
        printf "Packer version is too low. Please install at least %s\n." \
            "$required_packer_ver"
        exit 1
    fi
    popd
done
