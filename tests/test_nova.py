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


@pytest.mark.parametrize("name", [
    pytest.param("nova-api", marks=pytest.mark.headnodes),
    pytest.param("nova-scheduler", marks=pytest.mark.headnodes),
    pytest.param("nova-consoleauth", marks=pytest.mark.headnodes),
    pytest.param("nova-conductor", marks=pytest.mark.headnodes),
    pytest.param("nova-novncproxy", marks=pytest.mark.headnodes),
    pytest.param("nova-scheduler", marks=pytest.mark.headnodes),
    pytest.param("nova-compute", marks=pytest.mark.worknodes),
    pytest.param("nova-api-metadata", marks=pytest.mark.worknodes),
])
def test_services(host, name):
    s = host.service(name)
    assert s.is_running
    assert s.is_enabled


@pytest.mark.bootstraps
@pytest.mark.rmqnodes
@pytest.mark.storageheadnodes
@pytest.mark.storagenodes
@pytest.mark.stubnodes
@pytest.mark.parametrize("name", [
    ("nova-api"),
    ("nova-scheduler"),
    ("nova-consoleauth"),
    ("nova-conductor"),
    ("nova-novncproxy"),
    ("nova-scheduler"),
    ("nova-compute"),
    ("nova-api-metadata"),
])
def test_services_not_installed(host, name):
    s = host.package(name)
    assert not s.is_installed
