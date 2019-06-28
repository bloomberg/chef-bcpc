#!/bin/bash -x

# Copyright 2019, Bloomberg Finance L.P.
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

http_proxy=${1}
https_proxy=${2}
if [ "${http_proxy}" != "" ] ; then
    echo 'Acquire::http::Proxy '\""${http_proxy}"\"';' | \
        sudo tee -a /etc/apt/apt.conf
    echo 'http_proxy='"${http_proxy}" | sudo tee -a /etc/environment
fi
if [ "${https_proxy}" != "" ] ; then
    echo 'Acquire::https::Proxy '\""${https_proxy}"\"';' | \
        sudo tee -a /etc/apt/apt.conf
    echo 'https_proxy='"${https_proxy}" | sudo tee -a /etc/environment
fi

sudo rm -f /etc/apt/apt.conf.d/70debconf
