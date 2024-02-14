#!/bin/bash -x

# Copyright 2024, Bloomberg Finance L.P.
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

set -e

function main {
    install_linters_linux
}

#
# GithubActions Runners have pipx[1] installed.
# pipx is a CLI-specific tool where each application runs in its own venv.
# For `ansible-lint`, this implies the need to inject ansible into its venv.
#
# [1]: https://github.com/pypa/pipx
#

function install_linters_linux {
    sudo apt-get install -y shellcheck

    sudo gem install cookstyle -v 7.32.1

    python3 -m venv --system-site-packages /tmp/linter_venv
    # shellcheck disable=SC1091
    source /tmp/linter_venv/bin/activate

    pip install -U pip setuptools virtualenv wheel
    pip install --force-reinstall \
        ansible \
        "ansible-compat<4" \
        "ansible-core>=2.15.0,<2.16" \
        ansible-lint==6.16.2 \
        bashate==2.1.1 \
        hacking==6.1.0 \
        pytest
}

main
