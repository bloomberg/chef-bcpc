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

import pytest


@pytest.mark.rmqnodes
@pytest.mark.parametrize("name", [
    ("rabbitmq-server"),
])
def test_services(host, name):
    # Since rabbitmq can be on headnodes if rmqnodes are not specified,
    # check whether the chef role is specified
    if 'role[rmqnode]' not in host.ansible.get_variables()['run_list']:
        pytest.skip("Host is a head node not expected to run rabbitmq")
    s = host.service(name)
    assert s.is_running
    assert s.is_enabled


@pytest.mark.bootstraps
@pytest.mark.worknodes
@pytest.mark.storagenodes
@pytest.mark.stubnodes
@pytest.mark.parametrize("name", [
    ("rabbitmq-server"),
])
def test_services_not_installed(host, name):
    if 'role[rmqnode]' in host.ansible.get_variables()['run_list']:
        pytest.skip("Host is a headnode expected to run rabbitmq")
    s = host.package(name)
    assert not s.is_installed
