#!/usr/bin/env bash

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

set -xue
set -o pipefail

apt_key_url=''
apt_url=''
http_proxy=''
https_proxy=''
operations_user=''
operations_user_ssh_pub_key=''
swap_size_gb=''

ARGUMENT_LIST=(
    "apt-key-url"
    "apt-url"
    "http-proxy"
    "https-proxy"
    "operations-user"
    "operations-user-ssh-pub-key"
    "swap-size-gb"
)

# read arguments
opts=$(getopt \
    --longoptions "$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "" \
    -- "$@"
)

eval set --"$opts"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apt-key-url)
            export apt_key_url="$2"
            shift 2
            ;;

        --apt-url)
            export apt_url="$2"
            shift 2
            ;;

        --http-proxy)
            export http_proxy=$2
            shift 2
            ;;

        --https-proxy)
            export https_proxy=$2
            shift 2
            ;;

        --operations-user)
            export operations_user="$2"
            shift 2
            ;;

        --operations-user-ssh-pub-key)
            export operations_user_ssh_pub_key="$2"
            shift 2
            ;;

        --swap-size-gb)
            export swap_size_gb=$2
            shift 2
            ;;

        *)
            break
            ;;
    esac
done

function main {
    create_operations_user
    configure_vagrant_user
    configure_apt
    upgrade_system
    download_debs
    configure_swap
    configure_linux_kernel
}

function create_operations_user {
    if [ ! "$(getent passwd "${operations_user}")" ]; then
        useradd --create-home --shell '/bin/bash' "${operations_user}"
        mkdir "/home/${operations_user}/.ssh"
        echo "${operations_user_ssh_pub_key}" > \
            "/home/${operations_user}/.ssh/authorized_keys"
        echo "${operations_user} ALL = (ALL) NOPASSWD: ALL" > \
            "/etc/sudoers.d/${operations_user}"
    fi
}

function configure_vagrant_user {
    group="operators"

    # create the operators group
    groupadd -f ${group}

    # add the vagrant user to the operators group
    usermod -a -G ${group} vagrant
}

function configure_apt {

    if [ -n "$apt_key_url" ]; then
        /usr/bin/wget -qO - "$apt_key_url" | /usr/bin/apt-key add -
    fi

    if [ -n "$apt_url" ]; then
cat << EOF > /etc/apt/sources.list
deb ${apt_url} bionic main restricted universe multiverse
deb ${apt_url} bionic-backports main restricted universe multiverse
deb ${apt_url} bionic-security main restricted universe multiverse
deb ${apt_url} bionic-updates main restricted universe multiverse
EOF
    fi

    apt-get update
}

# Taken from Ansible's dist upgrade logic for apt(8)
function upgrade_system {
    env DEBIAN_FRONTEND='noninteractive' DEBIAN_PRIORITY='critical' \
        apt-get -y \
            -o 'Dpkg::Options::=--force-confdef' \
            -o 'Dpkg::Options::=--force-confold' \
        dist-upgrade
}

function download_debs {
    apt-get install --download-only -y -t bionic-backports \
        bird2 init-system-helpers
    apt-get install --download-only -y chrony tinyproxy unbound
}

function configure_swap {
    if [ -n "$swap_size_gb" ]; then
        swap_file="/mnt/${swap_size_gb}G.swap"

        if [ ! -e "${swap_file}" ]; then
            fallocate -l "${swap_size_gb}G" "${swap_file}"
            chmod 600 "${swap_file}"
            mkswap "${swap_file}"
        fi

        if ! sudo swapon -s | grep "${swap_file}"; then
            swapon "${swap_file}"
        fi

        if ! grep "${swap_file}" /etc/fstab; then
            echo "${swap_file}  none  swap  sw 0  0" >> /etc/fstab
        fi
    fi
}

function configure_linux_kernel {
    KERNEL_VERSION_FILE=/vagrant/kernel-version
    if test -f "${KERNEL_VERSION_FILE}"; then
        # shellcheck disable=SC1090
        source "${KERNEL_VERSION_FILE}"
        apt-get install -y "linux-${KERNEL_VERSION}"
    fi

    # Disable IPv6
    eval "$(grep ^GRUB_CMDLINE_LINUX= /etc/default/grub)"
    NEW_CMDLINE="${GRUB_CMDLINE_LINUX} ipv6.disable=1"
    sed -i.orig \
        "s/^[#]*GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"${NEW_CMDLINE}\"/" \
        /etc/default/grub
    update-grub
}

main
