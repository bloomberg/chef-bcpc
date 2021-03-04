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

import pytest


@pytest.mark.headnodes
@pytest.mark.parametrize("name", [
    ("cinder-volume"),
    ("cinder-scheduler"),
])
def test_services(host, name):
    s = host.service(name)
    assert s.is_running
    assert s.is_enabled

@pytest.mark.bootstraps
@pytest.mark.rmqnodes
@pytest.mark.worknodes
@pytest.mark.storagenodes
@pytest.mark.stubnodes
@pytest.mark.parametrize("name", [
    ("cinder-volume"),
    ("cinder-scheduler"),
])
def test_services_not_installed(host, name):
    s = host.package(name)
    assert not s.is_installed
