#!/bin/bash

# Source this file at the top of your script when needing VBoxManage
# e.g.,
# source ./virtualbox_env.sh

if [[ -z "$VBM" ]]; then

    if ! command -v VBoxManage >& /dev/null; then
        echo "VBoxManage not found!" >&2
        echo "  Please ensure VirtualBox is installed and VBoxManage is on your system PATH." >&2
        exit 1
    fi

    function check_version {
        local MIN_MAJOR=4
        local MIN_MINOR=3

        local IFS='.'
        local version="$(VBoxManage --version)"
        local version_array
        read -a version_array <<< "$version"

        if ! [[ "${version_array[0]}" -ge "$MIN_MAJOR" && \
                "${version_array[1]}" -ge "$MIN_MINOR" ]]
        then
            echo "ERROR: VirtualBox $version is less than $MIN_MAJOR.$MIN_MINOR.x!" >&2
            echo "  Only VirtualBox >= $MIN_MAJOR.$MIN_MINOR.x is officially supported." >&2
            exit 1
        fi
    }

    check_version
    unset -f check_version

    export VBM=VBoxManage
fi
