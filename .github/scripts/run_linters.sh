#!/bin/bash -x

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

set -ev

function main {
    cd /tmp/linter_venv && source bin/activate

    find "${GITHUB_WORKSPACE}" -name "*.sh" -exec shellcheck {} \;
    find "${GITHUB_WORKSPACE}" -name "*.sh" -exec bashate -e E006 {} \;
    find "${GITHUB_WORKSPACE}" -name "*.py" \
         ! -path "${GITHUB_WORKSPACE}/chef/cookbooks/bcpc/files/default/*" -exec flake8 {} \;
    ansible-lint -x var-naming -x meta-no-info -x meta-no-tags "${GITHUB_WORKSPACE}/ansible/"
    cookstyle --version && cookstyle "${GITHUB_WORKSPACE}"
}

main
