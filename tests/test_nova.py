import pytest

@pytest.mark.headnodes
@pytest.mark.parametrize("name", [
    ("nova-api"),
    ("nova-scheduler"),
    ("nova-consoleauth"),
    ("nova-conductor"),
    ("nova-novncproxy"),
    ("nova-scheduler"),
])
def test_services_head(host, name):
    s = host.service(name)
    assert s.is_running
    assert s.is_enabled

@pytest.mark.worknodes
@pytest.mark.parametrize("name", [
    ("nova-compute"),
    ("nova-api-metadata"),
])
def test_services_work(host, name):
    s = host.service(name)
    assert s.is_running
    assert s.is_enabled
