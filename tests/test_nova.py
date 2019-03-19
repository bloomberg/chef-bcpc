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
def test_services_head(host, name):
    s = host.service(name)
    assert s.is_running
    assert s.is_enabled
