import pytest


@pytest.mark.parametrize("name", [
    pytest.param("rabbitmq-server", marks=pytest.mark.headnodes),
])
def test_services_head(host, name):
    s = host.service(name)
    assert s.is_running
    assert s.is_enabled
