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
    find . -name "*.sh" -exec shellcheck {} \;
    find . -name "*.sh" -exec bashate -e E006 {} \;
    find . -name "*.py" -exec flake8 {} \;
    find ansible -name "*.yml" -exec ansible-lint -x 503 {} \;
    foodcritic chef/cookbooks --tags -FC004
    cookstyle .
}

main
