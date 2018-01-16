#!/bin/bash
# Exit immediately if anything goes wrong, instead of making things worse.
set -e

. "$REPO_ROOT"/bootstrap/shared/shared_functions.sh

# Set this to max value to ensure leftover mon VMs are destroyed
export CLUSTER_NODE_COUNT_OVERRIDE=6
cd "$REPO_ROOT"/bootstrap/vagrant_scripts && vagrant destroy -f || true
