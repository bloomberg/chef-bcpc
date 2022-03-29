#!/usr/bin/env bash

# Copyright 2022, Bloomberg Finance L.P.
#
# Chef Bento
# Copyright 2012-2019, Chef Software, Inc.
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

export DEBIAN_FRONTEND='noninteractive' DEBIAN_PRIORITY='critical'

apt_key_url="${BCC_APT_KEY_URL}"
apt_url="${BCC_APT_URL}"
http_proxy_url="${BCC_HTTP_PROXY_URL}"
https_proxy_url="${BCC_HTTPS_PROXY_URL}"
kernel_version="${BCC_KERNEL_VERSION}"

function main {
    configure_apt
    upgrade_system
    configure_linux_kernel
    cleanup_image
    download_debs
    sync
}

function configure_apt {
    if [ -n "${apt_key_url}" ]; then
        /usr/bin/wget -qO - "${apt_key_url}" | /usr/bin/apt-key add -
    fi

    if [ -n "${http_proxy_url}" ]; then
        echo 'Acquire::http::Proxy "'"${http_proxy_url}"'";' \
            > /etc/apt/apt.conf.d/proxy
    fi
    if [ -n "${https_proxy_url}" ]; then
        echo 'Acquire::https::Proxy "'"${https_proxy_url}"'";' \
            >> /etc/apt/apt.conf.d/proxy
    fi

    echo 'APT::Install-Recommends "false";' \
        > /etc/apt/apt.conf.d/99no-install-recommends

    if [ -n "${apt_url}" ]; then
cat << EOF > /etc/apt/sources.list
deb ${apt_url} bionic main restricted universe multiverse
deb ${apt_url} bionic-backports main restricted universe multiverse
deb ${apt_url} bionic-security main restricted universe multiverse
deb ${apt_url} bionic-updates main restricted universe multiverse
EOF
    fi

    apt-get update
}

# Based on Ansible's dist upgrade logic for apt(8)
function upgrade_system {
    apt-get -y \
        -o 'Dpkg::Options::=--force-confdef' \
        -o 'Dpkg::Options::=--force-confold' \
    dist-upgrade
}

function configure_linux_kernel {
    if [ -n "${kernel_version}" ]; then
        apt-get install -y \
            "linux-${kernel_version}" "linux-tools-${kernel_version}"
    fi

    # Disable IPv6
    eval "$(grep ^GRUB_CMDLINE_LINUX= /etc/default/grub)"
    NEW_CMDLINE="${GRUB_CMDLINE_LINUX} ipv6.disable=1"
    sed -i.orig \
        "s/^[#]*GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"${NEW_CMDLINE}\"/" \
        /etc/default/grub
    update-grub
}

# Based on Chef Bento's cleanup logic for Ubuntu
function cleanup_image {
    # autoremoving packages and cleaning apt data
    apt-get -y --purge autoremove
    apt-get -y clean
    apt-get -y purge libfakeroot

    # remove /var/cache
    find /var/cache -type f -exec rm -rf {} \;

    # truncate any logs that have built up during the install
    find /var/log -type f -exec truncate --size=0 {} \;

    # blank netplan machine-id (DUID) so machines get unique ID generated on
    # boot
    truncate -s 0 /etc/machine-id

    # remove the contents of /tmp and /var/tmp
    rm -rf /tmp/* /var/tmp/*

    # force a new random seed to be generated
    rm -f /var/lib/systemd/random-seed

    # clear the history so our install isn't there
    rm -f /root/.wget-hsts
    export HISTSIZE=0

    # remove VirtualBox Guest Additions when libvirt is in use
    if [ "${BCC_BASE_BOX_PROVIDER}" == "libvirt" ]; then
        systemctl disable vboxadd
        systemctl disable vboxadd-service
        systemctl reset-failed
        rm -rf /opt/VBoxGuestAdditions-*
    fi
}

function download_debs {
    # Resynchronize package index files after above cleanup
    apt-get update
    apt-get install --download-only -y -t bionic-backports \
        bird2 init-system-helpers
    apt-get install --download-only -y chrony tinyproxy unbound
}

main
