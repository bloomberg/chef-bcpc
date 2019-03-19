import pytest


@pytest.mark.headnodes
@pytest.mark.parametrize("name", [
    ("glance-api"),
    ("glance-registry"),
])
def test_services_head(host, name):
    s = host.service(name)
    assert s.is_running
    assert s.is_enabled
