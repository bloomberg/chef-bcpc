#!/bin/bash -x

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
    python3 -m venv /tmp/linter_venv
    # shellcheck disable=SC1091
    source /tmp/linter_venv/bin/activate

    sudo apt-get install -y shellcheck
    pip install -U pip setuptools wheel
    pip install -I --force \
        ansible==4.10.0 \
        ansible-lint==5.4.0 \
        bashate==2.1.0 \
        hacking==4.1.0

    sudo gem install cookstyle -v 7.32.1
}

main
