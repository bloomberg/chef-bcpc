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

set -e

http_proxy=${1}
https_proxy=${2}

main() {
    export http_proxy=${http_proxy}
    export https_proxy=${https_proxy}
    sudo -E apt-get update
    sudo -E apt-get install --download-only -y bird tinyproxy unbound
}

main
